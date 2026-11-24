> 2026-11-18 更新：新独立网关已部署至香港 ECS，HTTPS 和 8 项真实 AI 公网验收均通过，证书自动续期已验证。最新架构、状态以 [Deployment.md](Deployment.md)、[API.md](API.md)、[Verification.md](Verification.md) 为准。下文为旧服务器迁移阶段的历史记录。

# SoulMark → INVERTER 服务迁移（2026-11-17）

## 发现的原工程

本地：`/Users/jjzhang/XCode_Projects/SoulMark`。其 origin 为 [SoulMark_Team](https://github.com/JJZHANG0/SoulMark_Team)。旧工程存在用户未提交修改，本次没有修改旧工程、数据库或生产部署。

- 服务器：`https://8-146-228-143.sslip.io`，Caddy → FastAPI → PostgreSQL。
- 模型：阿里云百炼／通义千问，旧代码支持文本分析、图片分析及实时语音。文本分析默认模型配置为 `qwen3.7-plus`；实际运行配置只能在服务器确认。
- 短信：旧后端 `external_auth.py` 支持阿里云普通短信和 PNVS 号码认证短信；无法仅凭源码确认生产环境当前选用哪种。
- 身份认证：手机号验证码换 JWT；`Authorization: Bearer …` 访问分析接口。
- 本地 `.env` 中存在模型配置，但验证时不能用于正常调用。没有把其内容或其他服务密钥复制到 INVERTER。

## 新版已实现

1. Profile → Account & AI：+86 手机号校验、发送验证码、60 秒重发等待、六位验证码登录、退出、服务连通检查。
2. 登录凭据保存在按服务地址隔离的 Keychain 中，设备解锁时可访问、仅限本设备；不进入 JSON 导出。令牌过期或 401 后要求重新登录。
3. URLSession 使用 HTTPS、无持久 Cookie／缓存、拒绝重定向，避免将验证码、手机号或令牌发送到另一个地址。
4. 复盘详情、六种探索报告、人物档案、认知依据、个人画像和挑战反馈均可主动请求分析。每次先展示准确的发送内容，再确认发送。
5. 原服务 `/reviews/analyze` 会读取该账户的旧 SoulMark 云端记忆；新界面明确告知。不会自动把新版的本机档案、图片或录音上传，也不自动保存分析为事实或记忆。
6. 原来的本地复盘、用户确认保存、记忆授权保持可用。网络错误不会生成模拟 AI 回复。

## 实际联调结果

使用随机生成的独立临时开发账户和虚构英文记录，不涉及用户个人内容：

| 请求 | 结果 |
| --- | --- |
| `GET /health/ready` | 200，服务器及数据库正常 |
| `POST /api/v1/auth/register` | 201 |
| `POST /api/v1/auth/login` | 200，获取令牌 |
| `POST /api/v1/reviews/analyze` | **502，`review_ai_connection_failed`** |
| `DELETE /api/v1/users/me` | 204，删除该临时测试账户 |

没有向真实手机号发送测试短信。因此，短信的客户端契约已验证，实际短信投递仍需用户在 App 中完成一次登录。

AI 目前被**旧服务器的上游连接错误**阻断。无法从公开响应确定是密钥、地域、模型、网络还是 SDK 配置；没有访问生产日志的权限，不应声称已修复。此 Mac 对服务器的 SSH 公钥认证失败，用户也确认暂不掌握部署入口。

## 取得服务器访问权限后的收尾

- 在阿里云控制台找到该 ECS 实例，使用控制台远程连接／运维登录；确认服务的部署负责人。不要把密钥放进聊天或 App。
- 在原部署内核对 `SOULMARK_QWEN_API_KEY`、`SOULMARK_QWEN_HTTP_API_URL`、`SOULMARK_QWEN_REVIEW_MODEL`、`SOULMARK_QWEN_ANALYSIS_URL` 的地域、工作空间、模型权限，以及容器证书／网络；查看服务端异常链。先用虚构文本验证模型调用，再验证 `/reviews/analyze`。
- 本仓库 `Backend/soulmark_extension/inverter.py` 提供新增的鉴权逐轮提问路由。复制为旧后端 `app/api/v1/inverter.py`，在 `create_app()` 导入 router 并 `application.include_router(inverter_router, prefix="/api/v1")`。无数据库迁移，无旧记录写入。
- 使用原后端依赖运行扩展测试；部署后用鉴权请求验证英文和中文，并加生产层的用户速率／费用限制。
- 新版 `BackendReflectionService` 已对齐该路由。为避免未部署接口造成误导，当前 UI 不开放联网逐轮提问开关，仍使用本地五步引导。部署验证成功后再开放。

官方参考：[Qwen Chat Completions API](https://help.aliyun.com/en/model-studio/qwen-api-via-openai-chat-completions)、[Apple 无线运行设备上的 App](https://help.apple.com/xcode/mac/current/en.lproj/dev3e2f4ee6d.html)。
