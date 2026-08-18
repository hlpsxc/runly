# Runly

**Run anything. Automatically.**

[中文文档](README-CN.md)

Runly is a **native macOS menu bar scheduler** for developers and AI agents. Turn any CLI (`python`, `node`, `ffmpeg`, `git`, `claude`, `codex`, `items`, …) into a local task you can schedule, track, and notify on.

```text
Schedule → Execute → Log → Notify
```

> 100% local · no accounts · no cloud sync · Apple native APIs · no third-party dependencies

---

## Features

### Menu Bar First

- Lives in the menu bar (SF Symbol bolt icon)
- At a glance: Running / Failed / Recent / Up Next
- Quick actions: New Task · Run Task · Stop · Open Runly · Settings
- Failed runs: View Logs / Run Again / Dismiss
- Hover and press highlight on rows
- No Dock icon by default (`LSUIElement`)

### English / Chinese UI

- Settings → Language: **System** · **English** · **中文**
- Affects Runly UI only; preference is stored locally and applies immediately

### Task types

| Type | Description |
| --- | --- |
| **Command** | Any executable + arguments (one argument per line) |
| **Script** | Script path; run directly if executable, otherwise pick an interpreter by extension (python3 / node / zsh …) |
| **Agent** | Claude / Codex / OpenClaw / Custom — still resolves to Executable + Arguments |

### Scheduling & execution

- **Schedule**: Once · Interval · Daily · Weekly · Weekdays (Mon–Fri)
- **Beijing time (UTC+8)**: Once / Daily / Weekly / Weekdays clock fields are always interpreted as Asia/Shanghai
- **Minute precision**: Once / Daily / Weekly / Weekdays use date & time pickers (to the minute); expressions store as `yyyy-MM-dd HH:mm`, `HH:mm`, or `Mon HH:mm`
- **In-process scheduler**: while Runly is running, it checks due tasks on a configurable interval (default 20 seconds). No launchd / cron.
- **Run in iTerm** (Settings, on when iTerm2 is installed): scheduled/manual tasks open an iTerm window so they inherit iTerm’s Screen Recording / Accessibility grants. Notification commands still run in the background.
- **Run Now**: run immediately without changing the schedule
- **Timeout / Retry**: kill on timeout; retry on failure
- **Stop**: cancel a running task
  - Main window toolbar / Logs tab / task list context menu / menu bar Running section
  - Shortcut `⌘.`
  - SIGTERM first, then SIGKILL

### Environment & proxy

- Custom `KEY=VALUE` environment variables
- **Merge login shell environment by default** (exports from `~/.zshrc` / profile) so API keys work under the menu bar scheduler; toggle in Settings
- GUI apps get common PATH entries appended (Homebrew, etc.) **without replacing** an existing PATH
- Per-task HTTP / HTTPS / SOCKS / NO_PROXY (current process only)

### Logs & notifications

- Each run creates `TaskRun` metadata (SwiftData)
- Full output on disk: `~/Library/Application Support/Runly/Logs/<task-id>/`
  - Combined `.log` plus split `.out.log` / `.err.log`
- Live terminal-style log viewer
- System notifications (click to jump to the run)
- **Notification templates** (Settings): named commands shared across tasks; editing a template updates every task that uses it
- Per task: system notification · shared template · custom command
- Template variables: `{{task_name}}` `{{status}}` `{{exit_code}}` `{{duration}}` `{{stdout}}`

### Editor

- **Paste Command Line**: paste a full CLI (`\` continuations and quotes) → Command + Arguments
- Schedule UI: date/time pickers for Once · Daily · Weekly · Weekdays; text expression for Interval
- Placeholders / example hints hide once you type; replaced by parse or validation feedback
- Basic validation: empty command, unbalanced quotes, env format, missing paths, invalid schedule, … (errors block Save)
- **Command Preview** and **Test Run**

### Agent CLI / Skills

- Headless CLI for Cursor / Codex: `Runly --cli … --json`
- Commands: `list` · `get` · `create` · `run` · `stop` · `enable` · `disable` · `delete` · `status`
- Project skills: [`.cursor/skills/runly`](.cursor/skills/runly/SKILL.md) (Cursor) and [`skills/runly`](skills/runly/SKILL.md) (Codex / shared)
- Stuck `running` rows with no live child process are auto-marked **failed**

### Other

- **Launch at Login** (`SMAppService`) — required so schedules keep firing after reboot
- Main Dashboard: full CRUD, schedules, agents, history, and logs

---

## Requirements

- macOS 14+
- Xcode 15+ (full Xcode; Command Line Tools alone are not enough)

---

## Quick start

### 1. Clone and open

```bash
git clone git@github.com:hlpsxc/runly.git
cd runly
open Runly.xcodeproj
```

### 2. Run

In Xcode, choose **My Mac**, then press **⌘R**.

Look for the **bolt icon** in the menu bar (no Dock icon by default).

Or build from the CLI (point at full Xcode):

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Runly.xcodeproj -scheme Runly -configuration Debug -destination 'platform=macOS' build
```

### 3. Create your first task

1. Menu bar icon → **+ New Task** (or Open Runly → New Task)
2. Example:

| Field | Example |
| --- | --- |
| Name | Hello Runly |
| Type | Command |
| Command | `echo` |
| Arguments (one per line) | `hello from Runly` |
| Schedule | Interval · `Every day` |

Or paste into **Paste Command Line**:

```bash
echo "hello from Runly"
```

3. Check **Command Preview**; optionally **Test Run**
4. **Save**, then run from the detail page or menu bar **Run Task**

### 4. Agent example

| Field | Example |
| --- | --- |
| Type | Agent |
| Provider | Claude |
| Executable | `claude` |
| Prompt | `Summarize AI news for {{date}}` |
| Working Directory | `~/Projects/AIResearch` |

Prompt templates: `{{date}}` `{{time}}` `{{task_name}}` `{{working_directory}}` `{{prompt}}`

### 5. Shared notification templates

1. Settings → **Notification Templates** → Add Template  
2. Name it (e.g. `Webhook`), set a command (empty = system notification)  
3. Edit task → Notifications → Template → pick it  
4. Reuse across tasks; edit the template once to update all

### 6. Background schedules

Keep **Runly running** (Launch at Login recommended). Enabled tasks fire when the in-process poller sees `nextRunAt` in the past. Interval is **Settings → Check due tasks every N seconds** (default 20).

| Type | Expression (minute precision) | Example |
| --- | --- | --- |
| Once | `yyyy-MM-dd HH:mm` | `2026-08-20 09:30` |
| Daily | `HH:mm` | `23:05` |
| Weekly | `Mon HH:mm` (or `0`–`6` weekday) | `Fri 18:45` |
| Weekdays | `HH:mm` (Mon–Fri, Beijing) | `08:00` |
| Interval | natural language / seconds | `Every 5 minutes` · `Every 3 hours` |

### 7. CLI for agents (Cursor / Codex)

Build first, then point at the binary:

```bash
export RUNLY="$PWD/DerivedData/Build/Products/Debug/Runly.app/Contents/MacOS/Runly"
# or: /Applications/Runly.app/Contents/MacOS/Runly
```

```bash
"$RUNLY" --cli list --json
"$RUNLY" --cli create --name Hello --command echo --arg "hi" --json
"$RUNLY" --cli run Hello --json
"$RUNLY" --cli stop Hello --json
"$RUNLY" --cli status --json
"$RUNLY" --cli help
```

| Command | Purpose |
| --- | --- |
| `list` / `get` | Inspect tasks |
| `create` | Create command / script / agent tasks |
| `run` | Run now (blocks until finished) |
| `stop` | Stop the running process and mark DB state |
| `enable` / `disable` / `delete` | Lifecycle |
| `status` | Counts + running / failed summary |

Create options include `--type`, `--arg` (repeatable), `--cwd`, `--schedule-type`, `--schedule`, `--timeout`, `--provider`, `--prompt`, `--enabled` / `--disabled`.

```bash
# One-shot at a specific minute
"$RUNLY" --cli create --name Briefing --command echo --arg hi \
  --schedule-type once --schedule "2026-08-20 09:30" --json

# Every weekday morning (Mon–Fri 08:00 Beijing)
"$RUNLY" --cli create --name Standup --command echo --arg standup \
  --schedule-type weekdays --schedule "08:00" --json
```

Skills teach agents to use this CLI:

- Cursor: `.cursor/skills/runly/SKILL.md`
- Codex / shared: `skills/runly/SKILL.md`

---

## Usage notes

### Arguments

- **One argument per line**; spaces inside a line are preserved (good for prompts)
- Execution uses structured argv (not a concatenated shell string). With **Run in iTerm** on, the process is started inside iTerm instead of as a `Foundation.Process` child of Runly.
- Or paste a full CLI via Paste Command Line (quotes / `\` line breaks)

```text
Command:  claude
Arguments:
-p
Summarize model changes from the last 3 days
```

### PATH

GUI apps often see a different PATH than Terminal. Runly **appends** to the existing PATH:

```text
/opt/homebrew/bin
/opt/homebrew/sbin
/usr/local/bin
/usr/bin
/bin
…
```

You can also set `PATH=...` in the task Environment.

### Proxy (this task only)

When Proxy is enabled, env vars are set for the process, for example:

```text
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890
ALL_PROXY=socks5://127.0.0.1:7890
NO_PROXY=localhost,127.0.0.1
```

This does not change macOS system-wide proxy settings.

### Notifications

- **System notification**: macOS banner when a run finishes
- **Notification template**: manage in Settings; reference from tasks
- **Custom command**: per-task only; supports

```text
{{task_name}} {{status}} {{exit_code}} {{duration}} {{stdout}}
```

Prefer newline argv; one-liners with pipes/redirects may fall back to `zsh -lc`.  
Triggers (Always / On Success / On Failure / On Timeout) remain per-task.

### Language

Settings → General → Language:

| Option | Behavior |
| --- | --- |
| System | Chinese UI if the system language is Chinese; otherwise English |
| English | Force English |
| 中文 | Force Chinese |

### Data locations

| Data | Path |
| --- | --- |
| SwiftData | Application Support (Runly container) |
| Logs | `~/Library/Application Support/Runly/Logs/` |

---

## UI layout

```text
                 Runly
                   │
          ┌────────┴────────┐
          │                 │
      Menu Bar          Main Window
   status / quick run      config / history / logs
          │                 │
          └────────┬────────┘
                   │
                AppState
                   │
     TaskService · RunService
                   │
         NotificationTemplate (shared)
```

---

## Project layout

```text
Runly/
├── App/           # Entry, Settings
├── CLI/           # Agent-facing --cli (list/create/run/stop/…)
├── Models/        # RunlyTask, TaskRun, NotificationTemplate, enums
├── Services/      # AppState, Executor, Logs, Notifications, Templates…
├── Scheduler/     # Legacy LaunchAgent cleanup
├── Views/         # MenuBar, Dashboard, Editor, LogViewer
├── Utilities/     # PATH, templates, schedule, CLI parse, validation, L10n
└── Resources/     # Info.plist, Entitlements, Assets
```

Also: `.cursor/skills/runly` · `skills/runly` — agent skills for Cursor / Codex.
Stack: Swift · SwiftUI · SwiftData · Foundation.Process · UserNotifications · SMAppService

---

## Known limitations

- Only one in-app RunSession at a time
- Schedules fire only while the Runly process is running
- Notification commands with pipes/redirects may use a shell

---

## Development

```bash
# Point the CLI at full Xcode
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

open Runly.xcodeproj
# ⌘R
```

Optional: regenerate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.

---

## License

MIT (if a LICENSE file is added later, that file wins)

---

**Runly — A native macOS scheduler for commands and AI agents.**

[中文文档](README-CN.md)
