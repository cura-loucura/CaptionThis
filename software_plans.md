Goal: A live translation software made with Swift for MacOS using native translation tools. The user can start or stop the translation at will. The translation can be live (as spoken) or delayed (to wait to present only full sentences translated).


Technologies:

Speech Recognition (Live Transcription)
The Speech framework (Speech.framework) provides on-device speech recognition. Since iOS 13 / macOS 10.15, Apple has supported on-device recognition, and it has expanded significantly.

SFSpeechRecognizer handles the transcription
The language model downloads are Apple's on-device speech models
These are managed by the system and downloaded on-demand

Translation (Live Translation Output)
The Translation framework (Translation.framework) introduced in iOS 17.4 / macOS 14.4 provides on-device neural machine translation.

Uses TranslationSession for real-time translation
Supports 20+ language pairs
The language packs download on first use — these are system-level downloads stored in macOS, not bundled with the app

Screen/App Audio Capture
ScreenCaptureKit (macOS 13+) is used to capture audio from specific application windows.

Allows selecting individual apps as audio sources (e.g. Safari, media players)
Requires Screen Recording permission from the user
Provides per-app audio streams without capturing the full system audio



Languages to be supported initially, for both input and output:
English, Japanese, Portuguese, French (sorted alphabetically)


The interface:

When the app starts, it is simply a native application window with the following:


Title bar: CaptionThis
Header: <Language Input> -> <Caption Language> | Source: <Input option> | Live Translation (Yes/No) | Start/Pause buttons | Pin to top (Keep the window on top of others, yes/no) 
Input transcription: Read-only scrollable text area
Output transcription: Read-only scrollable text area

The window is resizable. The minimum size is fixed so the header width doesn't break and a relative area is available for both input and output.


Header options:
For languages, a drop-down menu with the available languages is available. Download of packages should be done before starting the translation.

Caption has an extra option on top (None), which will then be a simple transcription of the spoken language, therefore the Output transcription panel should be hidden with this option active.

Source can be microphone or an item in a list of available app windows (Safari, Media player, etc)

Live Translation yes means that the transcription and translation are running simultaneously. When off, the translation is run when SFSpeechRecognizer returns an isFinal segment (indicating a completed utterance), and only the finalized sentence is translated.

Start or Pause buttons are displayed, depending on the available action.

Pin to top if active will float the window above others, otherwise works as a normal window stack.


Example of header:
Japanes -> English | Source: Safari | Live translation (off) | Start | Pinned



The transcript and translation panels are simply a rolling text that is appended with either transcript or translation. It is read-only but selectable, so the user can copy and paste to another app.

Each panel has also the option to be cleared, which requires confirming a dialog to avoid wrongly pressed buttons.


Error Handling and Permissions:
The app requires Speech Recognition and Screen Recording (for app audio capture) permissions from the user. Standard macOS permission dialogs are presented on first use. If a permission is denied, an error dialog is shown explaining what is needed and how to enable it in System Settings.

For language packs (both speech recognition models and translation packs), the app attempts to download them automatically when a language is selected. If a download fails, an error dialog is shown and the user can retry. The app should check and attempt download each time a language is selected if the pack is not already available.


Persistence:
Language preferences (input language, caption language, source selection, live translation toggle, pin-to-top state) are saved between sessions using UserDefaults. On launch, the app restores the last used settings.





