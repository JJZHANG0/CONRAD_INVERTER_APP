# 独立 AI 网关部署

2026-11-18：香港 ECS `47.76.244.254`（`launch-advisor-20251120`）已上线。HTTPS 健康检查、未登录 401、十题短笺、复盘追问及六类解读全部通过真实公网请求验证。用户确认后签发 Let's Encrypt 证书，有效至 2027-02-16 12:42（北京时间）；续期演练通过，每天两次自动检查已启用。

## 地址与依赖

- App：`https://47-76-244-254.sslip.io`。
- 模型：`https://maas.qianwenaiapi.com/compatible-mode/v1`，`qwen3.7-plus`。
- 短信及账户：`https://8-146-228-143.sslip.io`。每次生成用原服务 `/api/v1/users/me` 校验 JWT；旧服务器不可达时登录和生成都会受影响。
- 用户答案只用于当前模型请求，新网关不读旧云端记忆、不写数据库。

服务器留存的 `www.blendlumina.com` 配置不是可用入口：其 DNS 已指向另一台服务器，留存证书也已过期。最初为该站点添加的 INVERTER 扩展已移出 Nginx，未修改该域名 DNS。

## 运行位置

- Python 3.12.16：`/opt/inverter/python`，独立虚拟环境 `/opt/inverter/venv`。
- 服务代码：`/opt/inverter/app/soulmark_extension`。
- 模型环境文件：`/opt/inverter/model.env`，root 所有、0600；不输出内容、不提交 Git。
- systemd：`/etc/systemd/system/inverter.service`，受限用户 inverter，监听 `127.0.0.1:8178`，开机自启。
- Nginx：`/www/server/panel/vhost/nginx/inverter.conf`；独立域名，128 KiB 请求上限；HTTPS 开启后转发至回环服务。
- Certbot：`/opt/inverter/certbot/bin/certbot`。HTTP 挑战目录 `/opt/inverter/acme`；证书位置 `/etc/letsencrypt/live/47-76-244-254.sslip.io/`。

`Backend/deployment/install.sh` 安装应用与服务，`configure_https.sh` 仅配置独立虚拟主机；脚本不自动接受新证书协议。证书签发后重新运行后者，再执行 `enable_renewal.sh` 配置每天两次检查的 systemd timer；续签成功后先检查 Nginx 配置再 reload。实际续期服务试运行返回 Result=success、ExecMainStatus=0，Certbot dry-run 成功。

## 证书自动续期

- 定时器：`inverter-certificate-renew.timer`，每天服务器时间 03:00、15:00 加最多 30 分钟随机延迟，持久化补跑。
- 服务：`inverter-certificate-renew.service`，只更新本应用证书，成功签发后测试并 reload Nginx。
- 检查：`systemctl list-timers inverter-certificate-renew.timer`；故障日志：`journalctl -u inverter-certificate-renew.service`。证书验证需要保持公网 80 端口挑战路径可达。

## 验证与维护

```sh
systemctl status inverter --no-pager
curl --fail http://127.0.0.1:8178/health/ready
curl --fail https://47-76-244-254.sslip.io/health/ready
```

公网验收用 `Scripts/VerifyGateway.py --endpoint https://47-76-244-254.sslip.io`：创建临时合成测试账户、验证未登录 401、十题短笺、逐轮追问及六类解读，最后删除该测试账户；不发送短信、不读取真实用户记录。健康接口只说明配置存在，不能替代真实模型联调。

修改代码或环境后运行 `systemctl restart inverter`。回滚时恢复备份代码并重启；移走独立 `inverter.conf` 后必须 `nginx -t` 成功再 reload，不覆盖其他站点。环境文件、含密钥部署包始终保留在 root 私有目录。

本机私有开发配置位于 `~/Library/Application Support/INVERTER Development/model.env`，部署包位于同目录 `deployment/`，均不进入仓库。

## 2026-11-18 连续聊天增量部署

新增 `chat.py` 并注册到 `gateway.py`，`inverter` 服务已重启并通过真实公网连续对话验收。更新前入口文件备份为 `/opt/inverter/gateway-before-chat.py`；未改动模型环境、证书或短信配置。上传文件会话过期后通过已授权 Workbench 终端传送无密钥代码包，最终使用 `install -m 644` 更新入口，避免 root 的 `cp -i` 别名干扰。

## 2026-11-18 主动引导与对话报告升级

更新 `chat.py` 支持 start / reply / finish、阶段推进、带逐字依据的结构化报告及安全分支。旧代码备份 `/opt/inverter/chat-before-guided.py`；代码 SHA-256 `68bd562fcf93bbe854d88f33cad811feb588d50c080bac9d38ca6d5e44ee50b5`。仍使用原模型环境、鉴权、证书和限制。服务 active / ready 已确认，真实公网五轮中文自动收束、英文开场与主动结束报告通过；测试账户已清理。

`Scripts/VerifyChat.py` 只使用虚构内容，覆盖主动开场、多轮引导、自动收束、英文部分回顾、依据逐字核对与 401 / 422；不发送短信。结果暂存在 `/tmp/inverter-guided-synthetic-results.json`，不含凭据。
