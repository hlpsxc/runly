#!/usr/bin/env bash
# Runly task template: summarize local Git repository changes without modifying files.
# Usage: bash examples/repo-summary.sh /absolute/path/to/repo
set -euo pipefail
if [[ $# -ne 1 || ! -d "$1" ]]; then
  echo "Usage: $0 /absolute/path/to/repo" >&2
  exit 2
fi
git -C "$1" rev-parse --show-toplevel
printf '\n-- Branch --\n'
git -C "$1" branch --show-current
printf '\n-- Working tree --\n'
git -C "$1" status --short
printf '\n-- Latest commit --\n'
git -C "$1" log -1 --format='%h %s (%cr)'
