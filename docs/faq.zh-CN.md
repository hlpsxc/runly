# 常见问题

English: [faq.md](faq.md)

## Runly 自带大模型吗？

不带。Runly 是**本地调度器**，调度你本机已安装的 CLI（Claude Code、Codex、脚本、FFmpeg、Git 等），命令使用当前用户权限执行。

## 为什么定时没触发？

1. 需要保持 Runly 在运行（建议打开「登录时启动」）。
2. 任务必须为**已启用**。
3. 日历时间按**任务时区**解释（未写入时区的旧任务仍按 Asia/Shanghai）。
4. 错过的执行采用 **醒来执行一次**：只跑过期槽位一次，然后排到「现在」之后，不会连续追赶多天。

## 找不到 Claude / Codex？

打开 **设置 → 本地 Agent**（或 `Runly --cli status --json`）查看 PATH 检测。安装对应 CLI，在终端确认 `which claude` / `which codex`，然后刷新检测。菜单栏应用可开启 **合并登录 Shell 环境**，以便使用 `~/.zshrc` 中的 PATH 与 API Key。

## 如何安装未签名预览版？

见 [install-unsigned.zh-CN.md](install-unsigned.zh-CN.md)。产物标注为 **未签名 / 未公证**。仅在拦截后使用「仍要打开」，不要关闭全局 Gatekeeper。

## 升级会清空任务吗？

一般不会。任务历史在 Application Support。跨 schema 升级前请按 [swiftdata-upgrade.md](swiftdata-upgrade.md) 备份。

## Mac 休眠或关机时任务会跑吗？

不会。当前没有 launchd 兜底。Runly 再次运行后才会继续调度。对比见 [compare-schedulers.zh-CN.md](compare-schedulers.zh-CN.md)。

## 日志里会隐藏密钥吗？

尽量脱敏，但不是安全边界。任务详情里敏感环境变量会显示为 `***`；实时日志与通知会遮蔽常见 token 形态。子进程仍可能把密钥打到输出里——请把 Application Support 下的日志当作敏感文件，不需要时手动删除。自动留存/清理尚未实现。
