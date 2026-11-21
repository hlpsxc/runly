# Runly 与 launchd / cron 对比

English: [compare-schedulers.md](compare-schedulers.md)

| | **Runly** | **launchd** | **cron** |
| --- | --- | --- | --- |
| 面向谁 | 本地 AI Agent 与开发者 CLI | 系统 / 用户守护任务 | 经典 Unix 定时 |
| 界面 | 菜单栏 + 编辑器 + 实时日志 | plist + `launchctl` | crontab 文本 |
| 时区 | 任务级 IANA | 通常系统时区 | 系统 / 实现相关 |
| 是否要常驻 | 是（应用进程） | 否（系统拉起） | 否（守护进程） |
| 休眠 / 关机 | 不触发 | 视任务定义，醒来可能补跑 | 错过的一般跳过 |
| 环境 / PATH | 可选合并登录 Shell + 任务环境 | plist 显式环境 | 环境极简，GUI 下常踩坑 |
| 密钥 | 存在任务环境；日志/UI 尽量脱敏 | 在磁盘 plist 中 | 在 crontab / 脚本中 |
| Agent 工作流 | Agent 任务类型 + CLI | 需自写包装 | 需自写包装 |
| 分发 | 目前未签名预览；签名后续 | 系统自带 | 系统自带 |

## 何时用 Runly

- 需要菜单栏查看即将运行 / 失败任务、日志与停止。
- 需要**任务级时区**、试运行、重试与通知。
- 调度本机已安装的 **Claude Code / Codex / 脚本**。

## 何时更适合 launchd / cron

- 即使没有 GUI 应用也必须执行。
- 需要 KeepAlive / WatchPaths / 网络触发等系统能力。
- 为其他机器交付无界面守护进程。

## 混合用法

交互式 Agent 调度用 Runly；确认稳定且必须「不打开 Runly 也跑」时，再迁到 launchd，并避免把密钥写进可被他人读取的 plist。
