# SwiftData upgrade verification

Runly persists tasks with SwiftData (`ModelConfiguration` name `Runly`). Adding optional fields is additive: existing stores should open without a custom migration plan as long as new properties are optional or have defaults.

## Time-zone field contract

| Record state | Scheduling zone |
| --- | --- |
| `scheduleTimeZoneIdentifier == nil` (pre-migration) | `Asia/Shanghai` |
| Empty / whitespace | Treated as legacy → `Asia/Shanghai` |
| Valid IANA id | That zone |
| Invalid stored typo | Runtime fallback `Asia/Shanghai` (UI/CLI reject new typos) |

Automated coverage: `tests/ScheduleTimeZoneSmoke.swift` asserts `nil` and `"Asia/Shanghai"` produce the same `nextRunAt` for Once / Daily / Weekly / Weekdays.

## Backup before upgrading the app

```bash
SUPPORT="$HOME/Library/Application Support"
# Default SwiftData location for configuration name "Runly"
ls -la "$SUPPORT" | grep -i runly

# Copy the whole Application Support folder entry that holds the store
# (exact filenames can include Runly.store / .sqlite companions depending on OS).
stamp=$(date +%Y%m%d-%H%M%S)
mkdir -p "$HOME/Desktop/runly-store-backup-$stamp"
cp -R "$SUPPORT"/Runly* "$HOME/Desktop/runly-store-backup-$stamp/" 2>/dev/null || true
# Also copy default SwiftData package if present under Application Support
find "$SUPPORT" -maxdepth 2 -iname '*runly*' -print
```

Keep the backup until you have confirmed schedules still fire at the expected absolute times.

## Manual upgrade checklist

1. On a Mac that already has Runly tasks from **before** the timezone field, note 2–3 tasks: type, expression, and expected next local Beijing time.
2. Quit Runly. Take the backup above.
3. Install / run the newer build (source or unsigned preview).
4. Open each noted task: timezone should show as system/legacy Beijing behavior for old rows (`Asia/Shanghai` until edited).
5. Confirm **Next Run** absolute instants match the pre-upgrade expectation (same UTC instant).
6. Create one **new** task without touching the timezone picker; confirm it stored the Mac’s current zone.
7. Change one legacy task Shanghai → Tokyo; confirm the wall-clock expression is unchanged and Next Run moves by the offset.
8. Quit and relaunch Runly; confirm overdue handling follows **run once on wake** (see below) and does not re-fire the same claimed slot.

Record results (macOS version, arch, pass/fail) in [install-unsigned.md](install-unsigned.md) when verifying a preview ZIP.

## Missed-run policy (process restart)

Default policy: **run once on wake**.

- When Runly starts (or the due poller runs) and `nextRunAt` is overdue, it fires **that slot once**.
- It then persists the next occurrence **strictly after now**, skipping a multi-day backlog catch-up chain.
- The claim is saved on the **same** SwiftData `ModelContext` used by task/run services **before** the run starts, so a crash mid-run does not re-fire the same slot after restart. If the run never starts (session busy), the claim is rolled back.
- Tasks do not run while the Mac is powered off or Runly is quit; there is no launchd fallback today.

## Restore from backup

Quit Runly, replace the store files with the backup copies, then reopen the app. If the store fails to open, restore the backup and file an issue with the macOS / app version.
