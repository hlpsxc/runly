# Runly vs launchd / cron

中文版：[compare-schedulers.zh-CN.md](compare-schedulers.zh-CN.md)

| | **Runly** | **launchd** | **cron** |
| --- | --- | --- | --- |
| Audience | Local AI agents & developer CLIs | System / user daemons | Classic Unix jobs |
| UI | Menu bar + task editor + live logs | plist + `launchctl` | Crontab text |
| Time zones | Per-task IANA zone | Usually system zone | System / implementation-defined |
| Must stay running? | Yes (app process) | No (system starts jobs) | No (daemon) |
| Sleep / power off | Does not fire | May catch up on wake depending on job | Missed ticks typically skipped |
| Env / PATH | Optional login-shell merge + per-task env | Explicit plist `EnvironmentVariables` | Minimal; often surprises GUI users |
| Secrets | Stored in task env; redacted in logs/UI best-effort | In plist on disk | In crontab / scripts |
| Agent workflows | First-class Agent task type + CLI | DIY wrappers | DIY wrappers |
| Distribution | Unsigned preview now; signed later | Built into macOS | Built into macOS / Linux |

## When to use Runly

- You want a **menu-bar** view of upcoming / failed agent runs with logs and Stop.
- Jobs need **per-task time zones**, Test Run, retries, and notifications.
- You are scheduling **Claude Code / Codex / scripts** you already installed.

## When launchd / cron is better

- The job must run **even when no GUI app is open**.
- You need OS-managed KeepAlive / WatchPaths / network triggers.
- You are shipping a headless daemon for other users’ machines.

## Hybrid tip

Use Runly for interactive agent schedules. Promote a proven job to launchd only when you need execution without Runly open — and keep secrets out of world-readable plists.
