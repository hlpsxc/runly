# Runly — Roadmap & Follow-up TODO

> Last updated: 2026-11-21. Tracks remaining work after open-source readiness, per-task time zones, unsigned-preview tooling, scheduling reliability hardening, and agent onboarding on `main`.
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
- [x] Define missed-run policy **run once on wake**; persist schedule claim before starting a due run (no silent `try?` save).
- [x] Document SwiftData upgrade / backup / restore and migration contract (`docs/swiftdata-upgrade.md`).
- [x] Automate nil-zone ≡ Asia/Shanghai and missed-run backlog skip in smoke tests.
- [x] Detect local agent CLIs with setup hints (Settings / editor / CLI status).
- [x] Empty-state sample task + bilingual FAQ for preview onboarding.
- [x] Best-effort secret redaction + launchd/cron comparison docs.
- [x] Harden unsigned preview packaging: Release-only ZIP, strip, refuse Debug dylib, scan for builder home paths; rename CI Debug artifact to `Runly-macOS-debug-ci-only`.
- [x] Publish first unsigned preview [`v0.1.0-preview.1`](https://github.com/hlpsxc/runly/releases/tag/v0.1.0-preview.1); verified no `/Users/…` builder paths and no Debug dylib in the ZIP.

## P0 — Still verify on real hardware / CI

- [x] **CI build (5d28c38):** macOS Build green after the smoke-test compile fix ([run](https://github.com/hlpsxc/runly/actions/runs/44750983405)).
- [x] **CI build (d742541):** missed-run / upgrade-doc follow-up green on `main`.
- [ ] **Real SwiftData migration:** Follow [docs/swiftdata-upgrade.md](docs/swiftdata-upgrade.md) on a machine with a pre-timezone store; verify old `nextRunAt` absolute instants.
- [ ] **Legacy schedules:** Manually confirm Once / Daily / Weekly / Weekdays / migrated cron still match China-time instants unless the zone is changed.
- [ ] **New schedules:** Confirm Mac system timezone capture (GUI + CLI) and that later OS timezone changes do not rewrite stored task zones.
- [ ] **Race/restart behavior:** On a clean Mac, quit mid-run and with overdue slots; confirm no duplicate fire of the same claimed slot and that backlog does not catch up day-by-day.
- [ ] **Clean-Mac preview check:** Verify ZIP extraction, SHA256, Gatekeeper **Open Anyway** flow, and record macOS/arch in `docs/install-unsigned.md`.

### Acceptance criteria

1. All previously stored tasks retain their intended firing time after upgrade without user edits.
2. Every new calendar schedule uses its selected IANA timezone consistently in UI, persistence and execution; intervals remain elapsed seconds.
3. `nextRunAt` stays correct across restarts, DST boundaries and schedule edits; overdue handling matches **run once on wake**.
4. macOS CI passes and a real SwiftData upgrade test is documented (checklist exists; human run still required).

## P0 — Installation & release distribution

- [x] Add a downloadable macOS app package path (unsigned ZIP) through GitHub **pre-releases**.
- [ ] Configure Developer ID signing, hardened runtime and Apple notarization; test Gatekeeper on a clean Mac.
- [x] Add a versioned release workflow with checksums; keep unsigned preview artifacts clearly labelled; keep CI test artifacts separate.
- [ ] Consider a Homebrew Cask **after** the public signed installer is verified.
- [x] Document upgrade/uninstall paths and persistence/backup of task history (unsigned guide + SwiftData upgrade doc).

### Unsigned distribution first (no Apple Developer account required)

**Decision:** Runly initially ships a clearly labeled **unsigned preview ZIP** via GitHub pre-releases. Do not block early adoption on a paid Apple Developer Program membership.

- [x] Confirm macOS CI passes, including timezone and missed-run smoke tests, before publishing any downloadable preview (`d742541` green).
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

- [x] Define missed-run semantics baseline (`run once on wake`) and document clock-powered-off limitation.
- [ ] Optionally expose missed-run policy in Settings (`skip` vs `run once on wake`) if users need it.
- [ ] Evaluate `launchd`-backed scheduling or a robust background helper with explicit lifecycle and permission management.
- [ ] Define execution queue, concurrency limit, deduplication keys, task cancellation and retry/backoff.
- [ ] Persist in-flight run state and recover safely after process crashes, reboot and sleep/wake (beyond schedule-slot claims).
- [ ] Add integration tests for heavy load, overlaps, process termination and headless/GUI simultaneous access.
- [x] Clearly disclose that local tasks cannot run while the Mac is powered off.

## P1 — Agent experience and safety

- [x] Detect local Claude Code / Codex / OpenClaw executables and versions; show setup hints in Settings, task editor, and `status --json`.
- [ ] Provide validated task templates for common agent workflows with explicit working directory and limited permissions.
- [ ] Add per-task execution policies and approval controls; **never** silently enable permission-bypass flags.
- [x] Redact secrets in logs, notifications, CLI errors, and task-detail env UI (best-effort); document that auto retention/cleanup is still TODO.
- [ ] Add automatic log retention / cleanup policies and optional secure wipe.
- [ ] Summarize run outcomes (duration, exit code, changed files when safely available) without hiding full logs.
- [x] Add stable `--json` error `code` fields (`usage` / `not_found` / `invalid` / `failed`) with redacted messages.

## P1 — Product onboarding & growth

- [ ] Add real menu-bar, editor and log screenshots to `docs/media/` and embed a concise demo GIF in the README.
- [x] Offer a guided first-run sample task (`/bin/echo`, disabled schedule) from the empty state; use Test Run / Run Now for success/failed visibility.
- [x] Add a clear comparison with plain `launchd`/`cron` (`docs/compare-schedulers.md`).
- [x] Document common FAQ, permissions and known limitations in EN/ZH (`docs/faq.md`).
- [ ] Publish real case studies (scheduled Codex/Claude work, FFmpeg analysis, Git maintenance).
- [ ] Prepare a focused Show HN / developer-community post **after** installation and reliability are verified.

## P2 — Longer-term capabilities

- [ ] Import/export versioned task definitions (with secrets excluded).
- [ ] Task dependency DAG and reusable workflow templates (only if validated by real user demand).
- [ ] Metrics for task success/failure, duration, missed schedules and retry outcomes.
- [ ] Establish release cadence, triage labels and contributor-friendly starter issues.

## Implementation sequencing

1. **Now:** Land redaction + packaging hardening on `main`; publish `v0.1.0-preview.1` unsigned Release pre-release; run SwiftData upgrade + Gatekeeper checks on a clean Mac and fill the install-doc test table.
2. **Next:** Gather install feedback from the labeled preview.
3. **Then:** Optional Settings for missed-run policy; deeper in-flight recovery; concurrency limits; agent templates.
4. **Afterward:** Document real demos and start community promotion. Revisit Apple signing when adoption justifies it.

### References

- [PR #1 — Open-source readiness + time-zone migration](https://github.com/hlpsxc/runly/pull/1)
- [Unsigned preview install (EN)](docs/install-unsigned.md)
- [未签名预览安装 (ZH)](docs/install-unsigned.zh-CN.md)
- [SwiftData upgrade](docs/swiftdata-upgrade.md)
- [FAQ](docs/faq.md)
- [vs launchd/cron](docs/compare-schedulers.md)
- [Agent recipes](docs/agent-recipes.md)
- [Contribution guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
