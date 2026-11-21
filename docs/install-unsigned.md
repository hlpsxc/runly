# Install unsigned preview builds

> **Label: Unsigned / Not notarized.** These GitHub pre-release ZIPs are for early testing only. They are not equivalent to a Developer ID–signed and notarized installer.

中文说明见 [install-unsigned.zh-CN.md](install-unsigned.zh-CN.md).

## Download

1. Open the project’s [GitHub Releases](https://github.com/hlpsxc/runly/releases) page.
2. Choose a pre-release titled like `Runly vX.Y.Z-preview.N (unsigned preview)`.
3. Download both:
   - `Runly-macOS-unsigned.zip`
   - `SHA256SUMS`

Do not use CI workflow artifacts (now named `Runly-macOS-debug-ci-only`) as an install source. Those are **Debug** builds that can embed builder absolute paths. Only install the **Release** ZIP from a GitHub **pre-release**.

## Verify checksum

```bash
cd ~/Downloads
shasum -a 256 -c SHA256SUMS
```

The command should report `Runly-macOS-unsigned.zip: OK`.

## Install

1. Unzip the archive.
2. Drag `Runly.app` into `/Applications` (or another trusted location).
3. Open Runly from Applications (or Spotlight).

## Gatekeeper on unsigned apps

macOS may block the first launch of an unsigned app. Supported recovery path when you trust this GitHub source:

1. Attempt to open `Runly.app` once (the block dialog may appear).
2. Open **System Settings → Privacy & Security**.
3. Find the recent block message for Runly and choose **Open Anyway**.
4. Confirm the second prompt if shown.

**Do not** disable Gatekeeper globally, and **do not** strip the quarantine attribute (`xattr -d com.apple.quarantine …`) as the default install path. Those weaken system protections for every download.

## Upgrade / uninstall

- **Upgrade:** quit Runly, replace `Runly.app` with the newer build, then reopen. Task history lives in the app’s SwiftData store under the user’s Application Support data and is preserved across app-bundle replacements.
- **Uninstall:** quit Runly and move `Runly.app` to Trash. Delete Application Support data only if you also want to remove scheduled tasks and run history.
- **Legacy schedules:** tasks created before per-task time zones keep Asia/Shanghai interpretation until you change the zone in the editor.

## Tested targets (fill in when verifying)

| macOS | Arch | Result | Notes |
| --- | --- | --- | --- |
| _TBD_ | Apple Silicon | _TBD_ | Record after a clean-Mac smoke test |
| _TBD_ | Intel | _TBD_ | Optional |

## Later: signed distribution

A signed and notarized stable channel requires an Apple Developer Program membership, Developer ID signing, hardened runtime, and notarization. Until then, keep every preview release clearly labeled **Unsigned / Not notarized**.
