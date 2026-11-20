# Recipes: local automation with Runly

Runly executes existing CLIs locally. **Runly is not an LLM provider**: install and authenticate your preferred agent separately, and review agent permission settings before unattended execution.

## 1. Daily video inspection (fully local)

Prerequisites: FFmpeg installed. In Runly create a **Script** task pointing to `examples/video-inspect.sh` (or a **Command** task with executable `/bin/bash` and arguments: the script path and video path). Set the working directory to your project root. Choose Daily or Weekdays; enable a failure notification. Test Run before enabling the schedule.

The script emits ffprobe JSON with size, duration, and reported average bit rate. It neither uploads media nor alters the video.

## 2. Git repository status

Create a **Command** task that executes `/bin/bash` with arguments `/absolute/path/to/runly/examples/repo-summary.sh` and `/absolute/path/to/your/repo`. Set a weekday schedule. This recipe is read-only.

## 3. Machine health

Create a **Script** task pointing to `examples/system-check.sh`; schedule Daily and enable notification on failure. This checks disk and uptime only.

## 4. Claude Code / Codex scheduled agent tasks

1. Install the relevant CLI from its official source and complete interactive authentication.
2. Test the exact command manually in your Terminal, within a throwaway repository.
3. Create an **Agent** task in Runly. Pick a provider, set an explicit working directory, enter a narrowly scoped prompt, and use **Test Run**.
4. Restrict write permissions and review any unattended execution options supplied by your CLI. Do **not** add unsafe permission-bypass flags.
5. Enable scheduling only after examining the results and local logs.

Runly supports `{{date}}`, `{{time}}`, `{{task_name}}`, `{{working_directory}}`, `{{prompt}}` in Agent prompts. Actual available CLI flags depend on your installed provider/version and should be verified locally.

## Scheduling caveats

As currently implemented, Runly must remain running for scheduled tasks to fire. Daily/Weekly/Weekdays/Once clock fields currently use **Asia/Shanghai (UTC+8)**, regardless of your Mac's local timezone. A future change to time zone semantics must be coordinated with migration of existing schedules.

Do not put tokens in prompt text or notification output. Review `SECURITY.md` before executing untrusted code.
