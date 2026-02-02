Known Issues

1. Language pair limitations
Translation.framework may not support all language pair combinations directly. For example, Japanese <-> Portuguese may not be a direct pair and could require routing through an intermediate language (e.g. English). This needs to be tested for all supported combinations (English, Japanese, Portuguese, French) and handled gracefully if a direct pair is unavailable.

2. Sentence boundary detection still flawed
The delayed translation mode currently relies on SFSpeechRecognizer's isFinal segments to detect completed utterances. This may not align perfectly with natural sentence boundaries or long pauses in speech. The isFinal flag indicates the recognizer has finalized a segment, but the granularity and timing can vary by language and speaking style. A more sophisticated approach (e.g. tracking silence duration between partial results) may be needed in the future.

3. Download of language packs not clear when available


4. CaptureThis records the whole screen and not only the selected window

5. If the user makes multiple recordings in the same session, the timestamp of the transcript and translation are not continuous

6. On ScreenRecordingService.swift there is a switch type for .screen and .audio but none for .microphone. We need to figure out the best way to deal with that case.