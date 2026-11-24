# INVERTER API

新版服务源配置：`https://47-76-244-254.sslip.io`（香港独立网关，部署验收见 Verification.md）。原短信／账户身份仍由 `https://8-146-228-143.sslip.io` 管理。只接受 HTTPS；用户界面不提供服务器地址或 AI／本地处理选项。不要将阿里云凭据写入客户端。

## 复用的 SoulMark 接口

- `POST /api/v1/auth/phone/code`：`{"phone_number":"大陆手机号"}` → 202。
- `POST /api/v1/auth/phone/login`：`{"phone_number":"大陆手机号","code":"六位验证码"}` → `access_token`, `token_type`, `expires_in_seconds`。
- `GET /health/ready`：检查网关启动与模型配置；不代表上游模型实时可用，需真实请求验收。

旧版本的全局联网授权及二次发送预览已移除。新版在有效登录后，由用户点击生成／继续直接发起本次功能请求。图像、音频不会附带上传。新网关不读取旧账户记忆。分析结果仅在当前页面展示，不自动变更用户记录。

## 逐轮提问

`POST /api/v1/inverter/reflections/next`，Bearer 鉴权：

```json
{
  "turns": [{"role":"user","content":"I asked a friend to clarify our plans."}],
  "locale": "en",
  "nextFocus": "feeling"
}
```

`nextFocus` 取 `feeling`、`interpretation`、`need`、`action`。返回 `{"question":"…"}`。最多 12 轮、合计 24,000 字符；仅使用本次显式提供的上下文。系统行为由服务端固定，客户端不可注入 system 角色。

实现位于 `Backend/soulmark_extension/inverter.py`。上游不可用时返回清晰错误，不返回预设文本假装生成成功。

部署与线上验收见 [Deployment.md](Deployment.md) 和 [Verification.md](Verification.md)。

## 新用户十题短笺

`POST /api/v1/inverter/first-look`，Bearer 鉴权。请求包含 `answers`（十个稳定题目 ID 到选项 ID 的字典）、`language`（`en` / `zh`）和 `questionVersion`（`first-look-v1`）。缺题、多题、未知选项或版本不匹配返回 422。服务端从可信题库重建全部十题文本，不接受客户端 system prompt。

返回 `title`、`paragraph`、`invitation`、`evidenceQuestionIDs`。模型配置缺失为 503；上游失败、连接失败或结果不合约为 502。结果引用必须属于题库，不能用占位文案伪装 AI 成功。该路由不读取旧账户记忆、不写数据库。用户单次确认仅发送本次十题答案，客户端保存成功结果供导出；失败保留现有短笺。

实现及部署见 [FirstLook.md](FirstLook.md)。

## 统一功能解读

`POST /api/v1/inverter/analysis`，Bearer 鉴权，请求为 `transcript`（1–24000 字符）、`language`（`zh` / `en`）、`purpose`（`reflection` / `game` / `person` / `portrait` / `challenge` / `insight`）。返回 `title`、`reason`、`brief_advice`、`detailed_advice`。新版 App 全部改用此接口，不再请求旧 `/reviews/analyze`，因此不读取旧账号云端记忆。

独立网关的 `/api/v1/auth/phone/code` 与 `/api/v1/auth/phone/login` 保持原短信契约。网关用原服务的 `/api/v1/users/me` 校验每个生成请求的登录令牌；未登录／过期为 401，身份服务不可达为 503。正文上限 128 KiB，单 IP 每分钟最多 30 请求，全局最多 4 个同时生成请求；超限为 429。服务器只监听回环地址，HTTPS 由既有 Nginx 提供。

## 引导对话与报告

`POST /api/v1/inverter/chat`，Bearer 鉴权，使用相同千问配置。

请求包含 `action`（start / reply / finish，缺省 reply）、`language`（en / zh）、`messages`。start 必须为空历史；reply 以 user 结束；finish 可在 assistant 之后结束，但至少有一条用户消息。历史按 user / assistant 交替，最多 41 条，用户单条 4000 字符，assistant 6000，总计 36000；拒绝 system 角色与空白。

响应包含 `reply`、`stage`（connecting / experience / meaning / pattern / choice / closing）、`complete`、`safety`、`report`。报告字段为 title、summary、pattern、strengths、nextStep、invitation、evidence。依据是 1–3 个用户原文片段，逐字核对；分享海报不展示依据。模型若只缺失结束语、但报告完整，使用其生成的 invitation 作结束语，仍须通过报告与依据验证。

AI 主动开启话题，每轮聚焦一个问题，以阿德勒取向探索归属、意义、目的与关系，所有推测应保持可修正；不冒充心理咨询师、不诊断、不强迫用户继续。自动结束至少要求 5 条用户回答、合计 160 字符，并让模型判断具体经历、感受、意义和下一步是否足够。用户手动 finish 可以生成较短、标明不确定的部分回顾。安全分支不会自动生成成长海报。

沿用限流、并发、45 秒模型超时与 HTTPS。新网关不读旧档案、不存对话、不自动添加记忆。客户端保留失败的消息，重试不重复插入；退出页面或后台取消请求。完整会话只存内存；回顾及依据通过本机受保护档案保存。

语音为 SFSpeechRecognizer 设备端识别和 AVSpeechSynthesizer 朗读交替进行，仅识别文字发送此接口。需要设备与所选语言支持离线识别；当前不是全双工实时音频服务。


## 四种引导模式 · 2026-11-24

`POST /api/v1/inverter/chat` 新增 `mode`：`emotions`、`relationships`、`understanding`、`action`。旧客户端省略时默认 `understanding`，未知值返回 422。所有 start / reply / finish 请求均携带模式；响应的 mode 由服务端回填，不信任模型生成的 mode。新版客户端要求响应模式匹配，避免旧后端静默忽略模式。

模式目标和完整提示词在 `Backend/soulmark_extension/chat.py` 的 `MODE_GUIDANCE`。各模式共有阿德勒取向的合作、鼓励、归属与意义探索，但有不同提问路径和收束条件：

| 模式 | 路径 | 收束目标 |
| --- | --- | --- |
| 情绪梳理 / 冰蓝 | 具体事件 → 感受 → 在意与需要 → 事实和解释 → 照顾需要 | 能说清感受、需要和一个自选的回应 |
| 关系边界 / 暖粉 | 相处片刻 → 连接需要 → 各自责任 → 边界 → 表达演练 | 明确自己的责任范围和一个请求／边界，也允许暂不接触 |
| 自我理解 / 淡紫 | 具体反应 → 个人解释 → 可能保护什么 → 例子与例外 → 修正模式 | 经用户确认或修正的一条暂定线索和一个替代可能 |
| 行动勇气 / 琥珀 | 想改变什么 → 顾虑 → 可控选择 → 资源 → 微小尝试 | 自选小行动、时间／情境、障碍与备选办法，也允许暂缓 |

每轮根据实际回答判断下一问，不机械逐项询问；一次一个问题、不重复已回答内容。自动收束仍至少需要 5 条用户回答、合计 160 字符，并要求模型判断当前模式目标已满足。目标判断属于模型判断，非确定性临床评估。用户手动结束可生成标明缺口的部分回顾。安全分支优先于所有模式，允许拒绝、换话题或停止，不诊断、不编造童年经历和动机。

界面四入口始终可见；有用户回答或未发送草稿时，切换前提示将结束当前聊天。取消保留原内容，确认后取消旧请求并清空上下文，避免串话；已保存报告保留。语音沿用当前模式，回顾保存模式并在图片上显示。历史无 mode 报告兼容读取。聊天仍只在当前进程保存。
