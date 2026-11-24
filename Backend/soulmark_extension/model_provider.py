"""Single server-side model configuration for every INVERTER feature."""
import os
from types import SimpleNamespace


def model_settings():
    legacy_key = None
    if not os.environ.get('INVERTER_AUTH_BASE_URL'):
        from app.core.config import get_settings
        legacy_key = get_settings().qwen_api_key
    return SimpleNamespace(
        qwen_api_key=os.environ.get('INVERTER_MODEL_API_KEY', legacy_key),
        qwen_analysis_base_url=os.environ.get('INVERTER_MODEL_BASE_URL', 'https://maas.qianwenaiapi.com/compatible-mode/v1').rstrip('/'),
        qwen_analysis_model=os.environ.get('INVERTER_MODEL', 'qwen3.7-plus'),
        qwen_analysis_timeout_seconds=45,
    )
