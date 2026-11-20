#!/usr/bin/env bash
# Runly task template: quick local system health check.
set -euo pipefail
printf '%s\n' '-- Timestamp --'
date -u '+%Y-%m-%dT%H:%M:%SZ'
printf '\n%s\n' '-- Disk space --'
df -h /
printf '\n%s\n' '-- System uptime --'
uptime
