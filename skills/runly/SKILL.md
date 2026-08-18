---
name: runly
description: >-
  Manage Runly macOS menu bar tasks via CLI — create, list, run, stop, enable,
  disable, delete scheduled commands and AI agents. Use when the user mentions
  Runly, menu bar scheduler, Runly tasks, or wants Codex/Cursor to create or
  stop local automated CLI/agent jobs on macOS.
---

# Runly CLI Skill

Control **Runly** (local macOS menu bar scheduler) from the shell. Prefer `--json` for machine-readable results.

## Binary

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
```

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
| `stop <id\|name> --json` | Stop running task |
| `enable` / `disable` | Toggle schedule |
| `delete <id\|name>` | Remove task |
| `status --json` | Summary |
| `help` | Usage |

## Create / Run / Stop

```bash
"$RUNLY" --cli create --name "Hello" --command echo --arg hi --json
"$RUNLY" --cli run Hello --json
"$RUNLY" --cli stop Hello --json
"$RUNLY" --cli list --json
```

Agent task:

```bash
"$RUNLY" --cli create \
  --name "Claude Brief" \
  --type agent \
  --provider claude \
  --prompt "Summarize AI news for {{date}}" \
  --json
```

## Rules

- Prefer UUID from `create`/`list` when names may collide.
- Never edit `Runly.store` directly.
- Logs live under `~/Library/Application Support/Runly/Logs/`.
- If Settings → Run tasks in iTerm is on, `run` opens an iTerm window (inherits iTerm TCC).
