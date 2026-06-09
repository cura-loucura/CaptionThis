# CaptureThis - Implementation Plan

## Feasibility Assessment

**Verdict: Feasible.** The existing codebase already uses ScreenCaptureKit for app audio capture and AVFoundation for audio processing. Extending to video capture, recording, compression, and merging is well-supported by native Apple frameworks. No external dependencies required.

**Key technical considerations:**
- The current `AppAudioCapture` creates an `SCStream` with a minimal 2x2 video surface. The video recording service will need its own `SCStream` configured for full-resolution video + audio capture.
- `AVAssetWriter` handles writing captured frames to disk as `.mov` files.
- `AVMutableComposition` + `AVAssetExportSession` handle merging and compressing video.
- Entitlements may need updating to include screen recording permission.

---

## Batch 1: Data Model, Settings & UI Dialog

**Goal:** Create the CaptureThis configuration model, persist settings, and build the settings dialog accessible from HeaderView.

### Files to create:
- `CaptionThis/Models/CaptureSettings.swift` - Data model for capture configuration
- `CaptionThis/Views/CaptureSettingsView.swift` - The CaptureThis dialog UI

### Files to modify:
- `CaptionThis/ViewModels/SettingsState.swift` - Add CaptureThis persistent settings
- `CaptionThis/Views/HeaderView.swift` - Add "CaptureThis" button
- `CaptionThis/Views/ContentView.swift` - Wire up the dialog sheet

### Tasks:

**1.1 - CaptureSettings model**
Create `CaptureSettings.swift` with:
```swift
struct CaptureSettings {
    var isEnabled: Bool              // Master toggle for screen capture
    var baseFileName: String         // Base name for all output files
    var outputDirectory: URL?        // Root folder (default: app support/captured/)
    var videoCodec: VideoCodec       // e.g., .h264, .hevc
    var videoBitrate: VideoBitrate   // e.g., .low, .medium, .high, .custom(Int)
    var videoResolution: VideoResolution // e.g., .native, .hd1080, .hd720
    var frameRate: Int               // e.g., 30, 24, 15
}
```
Include enums for `VideoCodec`, `VideoBitrate`, and `VideoResolution` with sensible defaults optimized for small file sizes (HEVC, medium bitrate, 1080p, 30fps).

**1.2 - Extend SettingsState**
Add CaptureThis settings to UserDefaults persistence:
- `captureBaseFileName` (String, default: "capture")
- `captureVideoCodec` (String, default: "hevc")
- `captureVideoBitrate` (String, default: "medium")
- `captureVideoResolution` (String, default: "hd1080")
- `captureFrameRate` (Int, default: 30)
- `captureOutputDirectory` (String, optional)
- `captureIsEnabled` should NOT be persisted (always false on restart per requirements)

**1.3 - CaptureSettingsView dialog**
Build a SwiftUI sheet with:
- Toggle to enable/disable screen capture
- TextField for base file name (with validation: no special chars, not empty)
- Picker for video codec (H.264 / HEVC)
- Picker for bitrate (Low ~2Mbps / Medium ~5Mbps / High ~10Mbps)
- Picker for resolution (720p / 1080p / Native)
- Picker for frame rate (15 / 24 / 30)
- Folder picker button for output directory (NSOpenPanel)
- Save / Cancel buttons
- Warning banner if `captured/<baseFileName>/` already exists

**1.4 - Add CaptureThis button to HeaderView**
Add a button labeled "CaptureThis" (or with a record icon) to the header bar, next to the existing controls. Tapping opens the CaptureSettingsView as a sheet.

**1.5 - Wire dialog into ContentView**
Add `@State var showCaptureSettings = false` and present the sheet.

### Acceptance criteria:
- CaptureThis button visible in header
- Dialog opens with all settings fields
- Settings persist across app launches (except `isEnabled`)
- Warning shown when folder already exists
- Dialog validates base file name input

---

## Batch 2: Screen Recording Service

**Goal:** Create a service that captures screen video + audio using ScreenCaptureKit and writes frames to a `.mov` file using AVAssetWriter.

### Files to create:
- `CaptionThis/Services/ScreenRecordingService.swift` - Core recording service

### Files to modify:
- `CaptionThis/CaptionThis.entitlements` - Add screen recording entitlement if needed
- `CaptionThis/Info.plist` - Add screen recording usage description if needed

### Tasks:

**2.1 - ScreenRecordingService**
Create a service that:
- Configures an `SCStream` for full display or specific window capture with proper resolution
- Sets up `SCStreamConfiguration` with video dimensions, frame rate, pixel format
- Implements `SCStreamOutput` to receive both video (`CMSampleBuffer` of type `.video`) and audio (`.audio`) frames
- Uses `AVAssetWriter` with `AVAssetWriterInput` for video (H.264/HEVC) and audio (AAC)
- Writes incoming frames to a `.mov` file at the configured path
- Handles start/stop/pause recording states
- Manages numbered raw file segments (e.g., `capture.mov`, `capture2.mov`, `capture3.mov`)
- Tracks recording state via an observable property

**2.2 - File segment management**
- On first start: create `capture.mov`
- On subsequent starts (after pause without completing): create `capture2.mov`, `capture3.mov`, etc.
- Track segment count in memory (resets on full completion)

**2.3 - Entitlements & permissions**
- Ensure screen recording permission is requested
- The app already uses ScreenCaptureKit, so the entitlement may already be implicitly available
- Add `NSScreenCaptureUsageDescription` to Info.plist if not present

### Acceptance criteria:
- Can start recording screen to a `.mov` file
- Can pause and resume recording (creates new segment file)
- Video and audio are properly synchronized in the output
- File sizes are reasonable (not raw uncompressed)
- Proper cleanup on errors

---

## Batch 3: Text File Output & Directory Management

**Goal:** Create the output directory structure and write transcription/translation text to files in real-time as they are produced.

### Files to create:
- `CaptionThis/Services/CaptureFileManager.swift` - Manages output directory and text files

### Files to modify:
- `CaptionThis/ViewModels/CaptionViewModel.swift` - Hook into transcription/translation pipeline to write text to files

### Tasks:

**3.1 - CaptureFileManager**
Create a service that:
- Creates the output directory: `<rootFolder>/captured/<baseFileName>/`
- Checks if directory already exists (returns bool for UI warning)
- Opens file handles for append-mode writing:
  - `<baseFileName>_transcription.txt`
  - `<baseFileName>_translation.txt`
- Provides methods: `appendTranscription(_ text: String)` and `appendTranslation(_ text: String)`
- Closes file handles on stop
- Formats text entries with timestamps for readability

**3.2 - Hook into CaptionViewModel**
When CaptureThis is active:
- Each time a transcription segment is finalized, append it to the transcription file
- Each time a translation segment is finalized, append it to the translation file
- Use the existing `segments` array updates as the trigger point
- Minimal changes to existing logic: add a check like `if captureSettings.isEnabled { fileManager.append(...) }`

### Acceptance criteria:
- Directory structure created correctly
- Transcription text written in real-time as segments finalize
- Translation text written in real-time as translations complete
- Files append correctly across pause/resume cycles
- File handles properly closed on stop

---

## Batch 4: Recording Lifecycle & State Coordination

**Goal:** Coordinate the CaptureThis recording lifecycle with the existing Start/Pause transcription flow, including the completion dialog.

### Files to create:
- `CaptionThis/Views/CaptureCompletionView.swift` - Dialog shown when pausing with active capture

### Files to modify:
- `CaptionThis/ViewModels/CaptionViewModel.swift` - Integrate recording start/stop with transcription lifecycle
- `CaptionThis/Views/ContentView.swift` - Present completion dialog

### Tasks:

**4.1 - State coordination**
Extend CaptionViewModel to manage capture state:
- When user presses "Start" and CaptureThis is enabled:
  - Start the ScreenRecordingService
  - Open text file handles via CaptureFileManager
- When user presses "Pause":
  - If CaptureThis is active, show the completion dialog instead of just pausing
  - Pause the ScreenRecordingService (stop writing to current segment)
  - Keep text file handles open (they just append)

**4.2 - CaptureCompletionView dialog**
When user pauses with active capture, show a dialog:
- "Do you want to complete the capture?"
  - **Yes, Complete** - Stops recording, triggers video processing (Batch 5), closes files, disables CaptureThis
  - **No, Continue Later** - Pauses recording, next start creates a new numbered segment
  - **Cancel** - Returns to recording state

**4.3 - Auto-disable on completion**
When capture is completed:
- Set `captureSettings.isEnabled = false`
- Recording state resets
- Text file handles closed

**4.4 - Startup behavior**
On app launch:
- CaptureThis is always disabled (not persisted)
- Previous settings (file name, codec, etc.) are restored
- No auto-start of recording

### Acceptance criteria:
- Recording starts/stops in sync with transcription
- Completion dialog appears on pause when capture is active
- "Continue Later" creates new numbered video segment on next start
- "Complete" triggers processing pipeline
- CaptureThis disables itself after completion
- Clean state on app restart

---

## Batch 5: Video Processing (Merge & Compress)

**Goal:** Merge multiple video segments into one file and compress to the target format/quality settings.

### Files to create:
- `CaptionThis/Services/VideoProcessingService.swift` - Merge and compress video files

### Files to modify:
- `CaptionThis/Views/ContentView.swift` - Add processing progress indicator
- `CaptionThis/ViewModels/CaptionViewModel.swift` - Trigger processing on capture completion

### Tasks:

**5.1 - VideoProcessingService**
Create a service that:
- **Merge**: Uses `AVMutableComposition` to concatenate multiple `.mov` segments into one timeline
- **Compress**: Uses `AVAssetExportSession` (or `AVAssetWriter` for more control) to export the merged composition with:
  - Target codec (H.264 or HEVC) from settings
  - Target bitrate from settings
  - Target resolution from settings
  - Audio passthrough or re-encode to AAC
- Output file: `<baseFileName>_final.<ext>` (`.mp4` for H.264, `.mp4` for HEVC)
- Raw `.mov` segments remain in the folder (as specified in requirements)
- Reports progress (0.0 - 1.0) for UI display

**5.2 - Progress UI**
Show a non-blocking progress indicator during video processing:
- "Processing video... X%" or a progress bar
- Prevent starting a new capture while processing
- Show completion message when done

**5.3 - Integration**
Wire the processing pipeline into the completion flow:
- User completes capture -> merge segments -> compress -> done
- On success: show completion notification
- On failure: show error alert, keep raw files intact

### Acceptance criteria:
- Multiple video segments merge into single file correctly
- Compressed output has significantly smaller file size than raw
- Audio/video stay in sync after merge
- Progress is reported to UI
- Raw files preserved
- Errors handled gracefully (raw files safe)

---

## Batch 6: Polish, Edge Cases & Testing

**Goal:** Handle edge cases, improve UX, and ensure robustness.

### Files to modify:
- Various files across the project

### Tasks:

**6.1 - Edge case handling**
- Single segment (no merge needed, just compress)
- Empty recording (user starts and immediately stops)
- Disk space warnings
- Permission denied for output directory
- App quit during recording (auto-stop and save)
- Very long recordings (file handle management)

**6.2 - UI polish**
- Recording indicator in header (red dot or similar) when CaptureThis is active
- Disable CaptureThis settings button while recording is active
- File size estimation in settings based on chosen quality
- Show output directory path in settings with "Open in Finder" button
- Keyboard shortcut for CaptureThis dialog

**6.3 - Validation & guards**
- Validate base file name (no `/`, `\`, `:`, or other filesystem-illegal chars)
- Trim whitespace from file names
- Prevent empty file names
- Check write permissions on output directory
- Handle case where output folder was deleted mid-capture

**6.4 - Testing**
- Test recording with different audio sources (microphone vs app audio)
- Test pause/resume with multiple segments
- Test merge with varying segment counts (1, 2, 5+)
- Test compression at different quality levels
- Test text file output with special characters and multiple languages
- Test disk full scenarios
- Test permission scenarios

### Acceptance criteria:
- All edge cases handled gracefully
- No data loss scenarios
- Clear error messages for user-actionable problems
- Recording state clearly visible in UI at all times

---

## Summary

| Batch | Focus | New Files | Modified Files | Complexity |
|-------|-------|-----------|----------------|------------|
| 1 | Model, Settings & Dialog UI | 2 | 3 | Low-Medium |
| 2 | Screen Recording Service | 1 | 2 | High |
| 3 | Text File Output & Directories | 1 | 1 | Low |
| 4 | Lifecycle & State Coordination | 1 | 2 | Medium |
| 5 | Video Merge & Compression | 1 | 2 | High |
| 6 | Polish & Edge Cases | 0 | Various | Medium |

**Total new files:** 6
**Key frameworks:** ScreenCaptureKit, AVFoundation, AVAssetWriter, AVMutableComposition

**Recommended order:** Batches should be implemented sequentially as each builds on the previous. Batch 2 (recording) and Batch 5 (video processing) are the most technically involved. Batches 1 and 3 are relatively straightforward. Each batch should be testable independently before moving to the next.
