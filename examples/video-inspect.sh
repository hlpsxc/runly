#!/usr/bin/env bash
# Runly task template: inspect a video file with ffprobe.
# Usage: bash examples/video-inspect.sh /absolute/path/to/video.mp4
set -euo pipefail
if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo "Usage: $0 /absolute/path/to/video" >&2
  exit 2
fi
if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffprobe is missing; install FFmpeg first." >&2
  exit 127
fi
ffprobe -v error -show_entries format=filename,duration,size,bit_rate -of json "$1"
