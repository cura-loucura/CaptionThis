import AVFoundation
import Speech
import ScreenCaptureKit

struct PermissionService {
    enum PermissionStatus {
        case authorized
        case denied
        case notDetermined
    }

    // MARK: - Microphone

    static var microphoneStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .authorized
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Speech Recognition

    static var speechRecognitionStatus: PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .authorized
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    static func requestSpeechRecognition() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Screen Recording (ScreenCaptureKit)

    /// Attempts to get shareable content — this triggers the system permission dialog
    /// if not yet authorized.
    static func requestScreenRecording() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Request All

    /// Requests all permissions needed for the app. Returns true only if all are granted.
    static func requestAllPermissions() async -> (microphone: Bool, speechRecognition: Bool) {
        async let mic = requestMicrophone()
        async let speech = requestSpeechRecognition()
        return await (microphone: mic, speechRecognition: speech)
    }
}
