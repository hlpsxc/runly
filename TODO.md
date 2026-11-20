# Runly — Roadmap & Follow-up TODO

> Last updated: 2026-11-20. This checklist tracks remaining work after the open-source readiness and per-task time-zone changes in [PR #1](https://github.com/hlpsxc/runly/pull/1).
>
> **Status convention:** `[x]` = code committed to the feature branch (not necessarily merged or verified); `[ ]` = not completed. Do not treat a committed feature as production-ready until its acceptance criteria pass.

## Delivered on the PR branch (pending merge)

- [x] Add an explicit MIT `LICENSE`, `CONTRIBUTING.md`, and `SECURITY.md`.
- [x] Update English/Chinese README positioning and onboarding.
- [x] Add macOS CI and a manually triggered **unsigned** release-candidate build.
- [x] Add local task recipes: video inspection, Git status, and system health.
- [x] Add a per-task time-zone identifier; newly created tasks default to the Mac's current zone.
- [x] Preserve `Asia/Shanghai` interpretation for existing records with a missing time-zone field.
- [x] Propagate the task's time zone across task editing, DatePicker, scheduling, and recalculation paths.
- [x] Add Foundation-only timezone regression smoke tests and wire them into CI.

## P0 — Verify time-zone migration before merging

- [ ] **CI build:** Confirm the macOS app compiles and `tests/ScheduleTimeZoneSmoke.swift` passes on the GitHub runner; fix failures.
- [ ] **Real SwiftData migration:** Back up an existing database from the released version and verify it loads after adding the optional time-zone field; verify old `nextRunAt` values remain correct.
- [ ] **Legacy schedules:** Verify old Once, Daily, Weekly, Weekdays and legacy cron migrations still execute at the same absolute instants (China time) unless users explicitly change zones.
- [ ] **New schedules:** Verify the Mac system timezone is captured when each new task is created, including via the headless CLI. Confirm behavior when the OS timezone changes later.
- [ ] **Timezone switch:** Edit a task from `Asia/Shanghai` to `Asia/Tokyo`; preserve its local wall-clock expression and recalculate `nextRunAt`. Show its next execution time clearly in the UI.
- [ ] **DST:** Test spring-forward nonexistent local times, fall-back repeated local times, cross-day and cross-week boundaries, plus Once schedules in zones observing DST.
- [ ] **Invalid timezone handling:** Validate IANA identifiers (UI and CLI) rather than silently accepting typos; make fallback behavior visible.
- [ ] **Picker completeness:** Support choosing any valid IANA timezone, not only the current short preset list; localize the UI labels to Chinese and English.
- [ ] **Race/restart behavior:** Verify the due watcher does not duplicate or skip tasks when timezones change, execution completes, the app restarts, or `nextRunAt` is overdue.
- [ ] **One-shot change behavior:** Specify whether switching timezone retains the entered clock time or absolute instant; protect already-fired tasks.
- [ ] **Test suite:** Add deterministic unit tests, including time-zone transitions, parser edge cases, invalid identifiers and data migration fixtures.
- [ ] **Review & merge:** Keep PR #1 in Draft until these checks pass; then review the full diff and merge to `main`.

### Acceptance criteria

1. All previously stored tasks retain their intended firing time after upgrade without user edits.
2. Every new calendar schedule uses its selected IANA timezone consistently in UI, persistence and execution; intervals remain elapsed seconds.
3. `nextRunAt` stays correct across restarts, DST boundaries and schedule edits.
4. macOS CI passes and a real SwiftData upgrade test is documented.

## P0 — Installation & release distribution

- [ ] Add a stable, downloadable macOS app package (ZIP/DMG) through GitHub Releases.
- [ ] Configure Developer ID signing, hardened runtime and Apple notarization; test Gatekeeper on a clean Mac.
- [ ] Add a versioned release workflow with checksums and a release changelog; keep unsigned test artifacts clearly labelled.
- [ ] Consider a Homebrew Cask **after** the public installer is verified.
- [ ] Document upgrade/uninstall paths and persistence/backup of task history.

## P1 — Scheduling reliability

- [ ] Define missed-run semantics (`skip`, `run once on wake`, `catch up` with bounds) and clock-skew behavior.
- [ ] Evaluate `launchd`-backed scheduling or a robust background helper with explicit lifecycle and permission management.
- [ ] Define execution queue, concurrency limit, deduplication keys, task cancellation and retry/backoff.
- [ ] Persist in-flight state and recover safely after process crashes, reboot and sleep/wake.
- [ ] Add integration tests for heavy load, overlaps, process termination and headless/GUI simultaneous access.
- [ ] Clearly disclose that local tasks cannot run while the Mac is powered off.

## P1 — Agent experience and safety

- [ ] Detect local Claude Code / Codex executables and versions; provide actionable setup instructions.
- [ ] Provide validated task templates for common agent workflows with explicit working directory and limited permissions.
- [ ] Add per-task execution policies and approval controls; **never** silently enable permission-bypass flags.
- [ ] Redact secrets in error messages, notifications and logs; define data retention and cleanup policies.
- [ ] Summarize run outcomes (duration, exit code, changed files when safely available) without hiding full logs.
- [ ] Improve CLI configuration/help and structured JSON error responses.

## P1 — Product onboarding & growth

- [ ] Add real menu-bar, editor and log screenshots to `docs/media/` and embed a concise demo GIF in the README.
- [ ] Offer a guided first-run task with a safe Test Run and visible success/failed states.
- [ ] Add a clear comparison with plain `launchd`/`cron` and other local scheduling approaches.
- [ ] Maintain English and Chinese docs in parallel; document common FAQ, permissions and known limitations.
- [ ] Publish real case studies (scheduled Codex/Claude work, FFmpeg analysis, Git maintenance).
- [ ] Prepare a focused Show HN / developer-community post **after** installation and reliability are verified.

## P2 — Longer-term capabilities

- [ ] Import/export versioned task definitions (with secrets excluded).
- [ ] Task dependency DAG and reusable workflow templates (only if validated by real user demand).
- [ ] Metrics for task success/failure, duration, missed schedules and retry outcomes.
- [ ] Establish release cadence, triage labels and contributor-friendly starter issues.

## Implementation sequencing

1. **Now:** Verify and harden the timezone change; run migration tests; merge PR #1 only after CI is green.
2. **Next:** Ship a signed and notarized installer with a trustworthy upgrade path.
3. **Then:** Improve missed-run handling, scheduling reliability and concurrency.
4. **Afterward:** Expand agent UX, document real demos, and start community promotion.

### References

- [PR #1 — Open-source readiness + time-zone migration](https://github.com/hlpsxc/runly/pull/1)
- [Agent recipes](docs/agent-recipes.md)
- [Contribution guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
