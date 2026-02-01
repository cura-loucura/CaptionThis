import Foundation
import ScreenCaptureKit

enum AudioSource: Identifiable, Hashable {
    case microphone
    case application(SCRunningApplication)

    var id: String {
        switch self {
        case .microphone:
            return "microphone"
        case .application(let app):
            return app.bundleIdentifier
        }
    }

    var displayName: String {
        switch self {
        case .microphone:
            return "Microphone"
        case .application(let app):
            return app.applicationName
        }
    }

    static func == (lhs: AudioSource, rhs: AudioSource) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
