# Runly — Roadmap & Follow-up TODO

> Last updated: 2026-11-20. Tracks remaining work after open-source readiness, per-task time zones, and the follow-up hardening / unsigned-preview work on `main`.
>
> **Status convention:** `[x]` = committed on `main` (not necessarily verified on a clean Mac); `[ ]` = not completed. Do not treat a committed feature as production-ready until its acceptance criteria pass.

## Delivered

- [x] Add an explicit MIT `LICENSE`, `CONTRIBUTING.md`, and `SECURITY.md`.
- [x] Update English/Chinese README positioning and onboarding.
- [x] Add macOS CI and a manually triggered **unsigned** preview release workflow.
- [x] Add local task recipes: video inspection, Git status, and system health.
- [x] Add a per-task time-zone identifier; newly created tasks default to the Mac's current zone.
- [x] Preserve `Asia/Shanghai` interpretation for existing records with a missing time-zone field.
- [x] Propagate the task's time zone across task editing, DatePicker, scheduling, and recalculation paths.
- [x] Add Foundation-only timezone regression smoke tests and wire them into CI.
- [x] Merge open-source readiness + timezone work to `main`.
- [x] Validate IANA identifiers in the task editor and CLI (`--timezone`); surface invalid input instead of silently accepting typos.
- [x] Support browsing any known IANA timezone (searchable sheet) plus common presets; localize timezone UI (EN/ZH).
- [x] Keep wall-clock expressions when switching zones; preview next run in the editor; protect already-fired Once tasks.
- [x] Show next-run times in the task's timezone in detail / menu-bar upcoming rows.
- [x] Expand timezone smoke coverage (validation, zone switch, DST fall-back, once-shot).
- [x] Extend the release workflow to accept an explicit version/tag and upload `Runly-macOS-unsigned.zip` + `SHA256SUMS` as a GitHub **pre-release**.
- [x] Publish bilingual unsigned install guides and label preview builds **Unsigned / Not notarized** in README.

## P0 — Still verify on real hardware / CI

- [ ] **CI build:** Confirm the macOS app compiles and `tests/ScheduleTimeZoneSmoke.swift` passes on the GitHub runner after this follow-up; fix failures.
- [ ] **Real SwiftData migration:** Back up an existing database from the released version and verify it loads after adding the optional time-zone field; verify old `nextRunAt` values remain correct.
- [ ] **Legacy schedules:** Verify old Once, Daily, Weekly, Weekdays and legacy cron migrations still execute at the same absolute instants (China time) unless users explicitly change zones.
- [ ] **New schedules:** Confirm Mac system timezone capture (GUI + CLI) and behavior when the OS timezone changes later (stored zone stays fixed).
- [ ] **Race/restart behavior:** Verify the due watcher does not duplicate or skip tasks when timezones change, execution completes, the app restarts, or `nextRunAt` is overdue.
- [ ] **SwiftData upgrade fixture:** Document a real upgrade test with a checked-in sample store or scripted backup/restore steps.
- [ ] **Clean-Mac preview check:** Verify ZIP extraction, SHA256, Gatekeeper **Open Anyway** flow, and record macOS/arch in `docs/install-unsigned.md`.

### Acceptance criteria

1. All previously stored tasks retain their intended firing time after upgrade without user edits.
2. Every new calendar schedule uses its selected IANA timezone consistently in UI, persistence and execution; intervals remain elapsed seconds.
3. `nextRunAt` stays correct across restarts, DST boundaries and schedule edits.
4. macOS CI passes and a real SwiftData upgrade test is documented.

## P0 — Installation & release distribution

- [x] Add a downloadable macOS app package path (unsigned ZIP) through GitHub **pre-releases**.
- [ ] Configure Developer ID signing, hardened runtime and Apple notarization; test Gatekeeper on a clean Mac.
- [x] Add a versioned release workflow with checksums; keep unsigned preview artifacts clearly labelled; keep CI test artifacts separate.
- [ ] Consider a Homebrew Cask **after** the public signed installer is verified.
- [x] Document upgrade/uninstall paths and persistence/backup of task history (unsigned guide).

### Unsigned distribution first (no Apple Developer account required)

**Decision:** Runly initially ships a clearly labeled **unsigned preview ZIP** via GitHub pre-releases. Do not block early adoption on a paid Apple Developer Program membership.

- [ ] Confirm macOS CI passes, including timezone migration and scheduling regression tests, before publishing any downloadable preview.
- [x] Extend the manual release workflow to accept an explicit version/tag and upload `Runly-macOS-unsigned.zip` plus `SHA256SUMS` to a **GitHub pre-release** (never auto-stable).
- [ ] Verify the app bundle, version metadata, ZIP extraction and SHA256 checksums on a clean Mac. Document which macOS versions and architectures were tested.
- [x] Publish a bilingual installation guide: download → checksum → Applications → open.
- [x] Explain Gatekeeper **Open Anyway**; never recommend disabling Gatekeeper globally or stripping quarantine as the default path.
- [x] Label preview builds `Unsigned / Not notarized` in Release notes templates and README.
- [ ] Test upgrade/uninstall and preservation of the SwiftData task database, including legacy Beijing-time schedules, on a clean Mac.

### Later: signed and notarized stable distribution

- [ ] Revisit Apple Developer Program membership when adoption justifies the recurring cost (typically USD 99/year; check local pricing then).
- [ ] Configure Developer ID Application certificate, hardened runtime and secure signing credentials in GitHub Actions.
- [ ] Implement `codesign` → `notarytool` → `stapler`, and verify the finished archive/DMG passes Gatekeeper on a clean Mac.
- [ ] Never expose signing certificates, private keys or Apple credentials in logs or repository history.
- [ ] Publish stable signed/notarized releases and consider a Homebrew Cask only after a tested public installer is available.

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

1. **Now:** Land timezone hardening + unsigned preview tooling on `main`; wait for CI green; run clean-Mac + SwiftData upgrade verification before publishing the first pre-release.
2. **Next:** Publish the first labeled unsigned preview; gather install feedback.
3. **Then:** Improve missed-run handling, scheduling reliability and concurrency.
4. **Afterward:** Expand agent UX, document real demos, and start community promotion. Revisit Apple signing when adoption justifies it.

### References

- [PR #1 — Open-source readiness + time-zone migration](https://github.com/hlpsxc/runly/pull/1)
- [Unsigned preview install (EN)](docs/install-unsigned.md)
- [未签名预览安装 (ZH)](docs/install-unsigned.zh-CN.md)
- [Agent recipes](docs/agent-recipes.md)
- [Contribution guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
