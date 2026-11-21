# FAQ

中文版：[faq.zh-CN.md](faq.zh-CN.md)

## Does Runly include an AI model?

No. Runly is a **local scheduler** for CLIs you already installed (Claude Code, Codex, scripts, FFmpeg, Git, …). Commands run with your user permissions.

## Why didn’t my schedule fire?

1. Runly must stay running (enable **Launch at Login**).
2. The task must be **Enabled**.
3. Calendar times use the **task time zone** (legacy rows without a zone stay on Asia/Shanghai).
4. Missed slots use **run once on wake** — one overdue fire, then the next occurrence after *now*, not a multi-day catch-up.

## Claude / Codex not found?

Open **Settings → Local Agents** (or `Runly --cli status --json`) to see PATH detection. Install the CLI, ensure it resolves in Terminal (`which claude` / `which codex`), then refresh detection. GUI apps may need **Merge login shell environment** so keys and PATH from `~/.zshrc` apply.

## How do I install an unsigned preview?

See [install-unsigned.md](install-unsigned.md). Builds are labeled **Unsigned / Not notarized**. Use Gatekeeper **Open Anyway** only after a blocked launch — never disable Gatekeeper globally.

## Will upgrading wipe my tasks?

Usually no. Task history lives under Application Support. Back up first using [swiftdata-upgrade.md](swiftdata-upgrade.md), especially across schema changes.

## Can tasks run while my Mac is asleep or off?

No. There is no launchd fallback today. Schedules resume when Runly is running again. See [compare-schedulers.md](compare-schedulers.md).

## Are secrets hidden in logs?

Best-effort only. Sensitive environment keys are masked in the task detail UI; live logs and notifications redact common token shapes (`Bearer …`, `sk-…`, `AKIA…`, `xox…`, `gh*_…`, and `KEY=value` for sensitive names). Child processes can still print secrets — treat log files under Application Support as sensitive and delete them when you no longer need them. Automatic retention/cleanup is not implemented yet.
