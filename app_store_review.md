# App Store Review — Feasibility Notes

_Last reviewed: 2026-06-09_

Honest assessment of whether CaptionThis can ship on the Mac App Store, grounded in the current App Review Guidelines and ScreenCaptureKit docs. Use this to decide whether to invest the engineering + policy work.

## Bottom line

Nothing in CaptionThis is *plainly forbidden*. The core architecture (ScreenCaptureKit + on-device Speech + on-device Translation) uses fully sanctioned APIs and would clear App Review on a good day. The pain is in three places:

1. The app isn't sandboxed today.
2. One framing risk under Guideline 5.2.3 (audio/video downloading).
3. The macOS-level monthly screen recording prompt — a UX nuisance you can't engineer your way out of.

## What would be rejected as-is

Two current implementation details would fail review:

- **Empty entitlements file.** `CaptionThis/CaptionThis.entitlements` is literally `<dict/>`. Mac App Store apps must be sandboxed (Guideline 2.4.5(i)). Direct distribution lets you skip the sandbox; the App Store does not.
- **Persisting `captureOutputDirectory` as a raw path.** In `SettingsState.captureOutputDirectory` you store the path string and rehydrate on launch. Under sandbox + Powerbox, the user grants implicit access only to paths chosen *that session* via `NSOpenPanel`; cross-launch access requires a **security-scoped bookmark**. Current code would silently fail to write to the saved folder after the next launch.

Both fixable.

## Grey areas, ranked by risk

### 1. Guideline 5.2.3 (audio/video downloading) — biggest single risk

> "Apps should not facilitate illegal file sharing or include the ability to save, convert, or download media from third-party sources (e.g. Apple Music, YouTube, SoundCloud, Vimeo, etc.) without explicit authorization from those sources."

Generic screen recorders are accepted (Apple ships QuickTime; many are on the Store). The risk is not the technical capability — it's the *framing*. The Source picker explicitly lists Safari/Zoom/Discord/VLC, and the README currently says "capture audio from a specific application (e.g., Safari, Zoom, VLC Player (DVD, video files), Discord)." A reviewer skimming that can decide the app is purpose-built to rip media.

Mitigations in order of importance:

- Reposition the pitch around **transcription / captioning / accessibility**. The Urasenke tea-ceremony use case is exactly the right framing — "transcribe educational content you can't otherwise caption."
- Drop the explicit "VLC (DVD, video files)" example from README and App Store metadata. DVD = DRM, an immediate red flag.
- Keep the source-app list dynamic (which it already is) rather than baking specific media-app names into the UI.

### 2. Guideline 2.5.14 (consent + recording indicator)

macOS shows its own purple screen-recording indicator in the menu bar (OS-level requirement satisfied). The app shows the red pulsing dot + "Recording" label in the action row (in-app indication satisfied). **You're fine here** after the recent toolbar refactor.

### 3. Persistent monthly screen-recording prompts

Since macOS Sequoia, apps using ScreenCaptureKit get re-prompted **monthly** for screen recording permission. The only way to suppress this is the `com.apple.security.application.persistent-content-capture` entitlement, which Apple restricts to VNC-style apps via an application form. CaptionThis almost certainly wouldn't qualify. Not a rejection — a UX nuisance with no engineering workaround.

### 4. Privacy policy (Guideline 5.1.1)

Required for the App Store. Easy because everything is genuinely on-device: "we don't collect or transmit anything." Worth having one even for direct distribution.

### 5. App Store category + naming

`LSApplicationCategoryType = utilities` is fine. The CaptionThis-vs-CaptureThis double-naming inside one app may draw a 2.3.1 (accurate metadata) note — clarify in App Store Connect's review notes that CaptureThis is the screen-recording feature, not a second app.

## Engineering work to get App Store-ready

Rough order:

1. **Turn on sandboxing** in the project and add the minimum entitlements:
   - `com.apple.security.app-sandbox` = true
   - `com.apple.security.device.audio-input` = true (mic)
   - `com.apple.security.files.user-selected.read-write` = true (chosen folder)
2. **Replace path storage with security-scoped bookmarks** in `SettingsState.captureOutputDirectory` so the chosen folder survives relaunches. Estimated ~50 lines of code.
3. **Verify ScreenCaptureKit works under sandbox.** It does (TCC-gated, no entitlement needed), but worth a clean-install test.
4. **Audit all file writes** for sandbox compliance — `CaptureFileManager` writes alongside the video, so should be covered by the same bookmark. Confirm the `~/Movies/CaptionThis` default fallback works without a separate `files.movies.read-write` entitlement.
5. **Write a short privacy policy** — "processes audio locally via Apple's on-device Speech & Translation frameworks; no data leaves your Mac; recordings stored only in folders you choose."
6. **Rewrite App Store description** around captioning/transcription/accessibility; drop DRM-adjacent examples.
7. **Add a "Review notes" entry** in App Store Connect explaining: (a) ScreenCaptureKit usage is for transcription, (b) only the user's selected window/app is captured, (c) all processing is on-device.

## Recommendation

For a one-person tea-ceremony recording tool, the App Store is significant engineering + policy overhead for limited benefit. macOS is one of the few platforms where **direct distribution + notarization** (the current model) is fully legitimate and even normal for power-user tools. If you go MAS, do it for discoverability — not because direct distribution has a problem.

## Sources

- [App Review Guidelines (current)](https://developer.apple.com/app-store/review/guidelines/)
- [Sequoia Screen Recording Prompts and the Persistent Content Capture Entitlement — Michael Tsai](https://mjtsai.com/blog/2024/08/08/sequoia-screen-recording-prompts-and-the-persistent-content-capture-entitlement/)
- [macOS Sequoia screen recording monthly prompts — 9to5Mac](https://9to5mac.com/2024/08/14/macos-sequoia-screen-recording-prompt-monthly/)
- [Is there an entitlement for screen recording? — Apple Developer Forums](https://developer.apple.com/forums/thread/683860)
- [What are app entitlements, and what do they do? — Eclectic Light Co.](https://eclecticlight.co/2025/03/24/what-are-app-entitlements-and-what-do-they-do/)
- [Guideline 5.2.3 discussion — TortugaPower/BookPlayer](https://github.com/TortugaPower/BookPlayer/discussions/682)
- [The infamous Apple Guideline 5.2.3 — EnDavid blog](http://endavid.com/index.php?entry=88)
