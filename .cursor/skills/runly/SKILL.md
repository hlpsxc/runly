---
name: runly
description: >-
  Manage Runly macOS menu bar tasks via CLI — create, list, run, stop, enable,
  disable, delete scheduled commands and AI agents. Use when the user mentions
  Runly, menu bar scheduler, Runly tasks, or wants Cursor/Codex to create or
  stop local automated CLI/agent jobs on macOS.
---

# Runly CLI Skill

Control **Runly** (local macOS menu bar scheduler) from the shell. Prefer `--json` for machine-readable results.

## Binary

Resolve the app binary (first that exists):

```bash
RUNLY="${RUNLY_BIN:-}"
if [ -z "$RUNLY" ]; then
  for c in \
    "$HOME/pcode/runly/DerivedData/Build/Products/Debug/Runly.app/Contents/MacOS/Runly" \
    "/Applications/Runly.app/Contents/MacOS/Runly"
  do
    [ -x "$c" ] && RUNLY="$c" && break
  done
fi
# Fallback: open project and build if missing
```

All commands:

```bash
"$RUNLY" --cli <command> [options] [--json]
```

## Commands

| Command | Purpose |
| --- | --- |
| `list --json` | List tasks |
| `get <id\|name> --json` | Task details |
| `create ... --json` | Create a task |
| `run <id\|name> --json` | Run now (blocks until finished) |
| `stop <id\|name> --json` | Stop running task (GUI + DB) |
| `enable` / `disable` | Toggle schedule |
| `delete <id\|name>` | Remove task |
| `status --json` | Counts + running/failed summary |
| `help` | Usage |

Exit codes: `0` ok · `2` usage · `3` not found · `1` other failure.

## Create

```bash
"$RUNLY" --cli create \
  --name "Daily Hot" \
  --type command \
  --command agent \
  --arg -p --arg --force --arg --output-format --arg text \
  --arg '执行 $dailyhot-news-analyst：…' \
  --schedule-type interval \
  --schedule "Every day" \
  --timeout 1200 \
  --enabled \
  --json
```

Agent example:

```bash
"$RUNLY" --cli create \
  --name "Claude Brief" \
  --type agent \
  --provider claude \
  --prompt "Summarize AI news for {{date}}" \
  --cwd "$HOME/Projects" \
  --json
```

Notes:

- `--arg` is repeatable (one argv line each). Or `--arguments $'line1\nline2'`.
- `--type` = `command` | `script` | `agent`
- `--schedule-type` = `once` | `interval` | `daily` | `weekly` | `weekdays`
- Name lookup is case-insensitive; prefer UUID if names collide.

## Run / Stop

```bash
"$RUNLY" --cli run "Daily Hot" --json
"$RUNLY" --cli stop "Daily Hot" --json
```

- `run` executes in the CLI process (like Run Now) and prints final status. If Settings → Run tasks in iTerm is on, this opens an iTerm window.
- `stop` notifies a running Runly GUI (if any) and marks open runs `cancelled`.

## Typical agent workflow

1. `"$RUNLY" --cli list --json` — see what exists  
2. Create or reuse a task  
3. `"$RUNLY" --cli run <id> --json` — execute now  
4. On hang / cancel — `"$RUNLY" --cli stop <id> --json`  
5. `"$RUNLY" --cli status --json` — overview  

## Data locations

- Store: `~/Library/Application Support/Runly.store`
- Logs: `~/Library/Application Support/Runly/Logs/<task-uuid>/`

## Do not

- Do not invent task UUIDs — create or list first.
- Do not edit the SwiftData store by hand.
- Do not use GUI-only assumptions; always drive via `--cli` from agents.
