"""Stage the additive routers into an authorized SoulMark checkout. Does not restart services.
Usage: python Scripts/InstallBackendExtension.py --target /srv/SoulMark_backend [--model-config /secure/model.env]
"""
import argparse
import ast
import os
import shutil
from datetime import datetime, timezone
from pathlib import Path


def install(target: Path, model_config: Path | None):
    source = Path(__file__).resolve().parents[1]
    main = target / 'app/main.py'
    current = main.read_text()
    marker = '    application = FastAPI(title=settings.app_name, version="0.1.0")'
    registration = '\n    from app.api.v1.inverter_feature import register\n    register(application)'
    if registration not in current:
        if marker not in current: raise ValueError('Unknown create_app structure; inspect before installation.')
        updated = current.replace(marker, marker + registration, 1)
    else: updated = current
    ast.parse(updated)
    # Validate configuration before any mutation, and preserve existing SMS/database settings.
    env = target / '.env.production'
    env_text = None
    if model_config:
        values = dict(line.split('=', 1) for line in model_config.read_text().splitlines() if line and not line.startswith('#'))
        required = {'INVERTER_MODEL_API_KEY', 'INVERTER_MODEL_BASE_URL', 'INVERTER_MODEL'}
        if not required <= values.keys() or not values['INVERTER_MODEL_API_KEY'] or not values['INVERTER_MODEL_BASE_URL'].startswith('https://'):
            raise ValueError('Model configuration is incomplete.')
        if not env.is_file(): raise ValueError('Production environment missing; do not create one with guessed database/SMS credentials.')
        lines = [line for line in env.read_text().splitlines() if line.split('=', 1)[0] not in required]
        env_text = '\n'.join(lines + [key + '=' + values[key] for key in sorted(required)]) + '\n'
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = target.parent / ('inverter-backup-' + stamp)
    backup.mkdir(mode=0o700)
    shutil.copy2(main, backup / 'main.py')
    destination = target / 'app/api/v1/inverter_feature'
    if destination.exists(): shutil.copytree(destination, backup / 'inverter_feature')
    if env_text is not None:
        shutil.copy2(env, backup / '.env.production'); (backup / '.env.production').chmod(0o600)
    destination.mkdir(exist_ok=True)
    for name in ('chat.py', 'analysis.py', 'first_look.py', 'inverter.py', 'model_provider.py', 'runtime.py'):
        shutil.copy2(source / 'Backend/soulmark_extension' / name, destination / name)
    shutil.copy2(source / 'INVERTER/Resources/FirstLookQuestions.json', destination / 'FirstLookQuestions.json')
    (destination / '__init__.py').write_text('''from .chat import router as chat_router
from .analysis import router as analysis_router
from .first_look import router as first_look_router
from .inverter import router as reflection_router

def register(application):
    for router in (analysis_router, first_look_router, reflection_router, chat_router):
        application.include_router(router, prefix="/api/v1")
''')
    main.write_text(updated)
    if env_text is not None:
        temporary = env.with_name('.env.production.inverter-pending')
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, 'w') as stream: stream.write(env_text)
        os.replace(temporary, env)
    print('Extension staged. Services have not been restarted. Backup:', backup)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', required=True, type=Path)
    parser.add_argument('--model-config', type=Path)
    args = parser.parse_args()
    install(args.target, args.model_config)
