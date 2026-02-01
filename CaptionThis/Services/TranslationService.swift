import Foundation
import Translation

actor TranslationService {
    private var sessions: [String: TranslationSession] = [:]

    /// Translates text from source language to target language.
    /// Uses two-hop fallback through English if direct pair is unavailable.
    func translate(
        text: String,
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) async throws -> String {
        guard source != target else { return text }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }

        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)

        // Try direct translation first
        let directKey = "\(source.rawValue)->\(target.rawValue)"
        do {
            let session = try await getOrCreateSession(
                key: directKey,
                from: sourceLocale,
                to: targetLocale
            )
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            // If direct pair fails and neither language is English, try two-hop
            if source != .english && target != .english {
                return try await twoHopTranslate(text: text, from: source, to: target)
            }
            throw error
        }
    }

    /// Prepares a language pair by downloading the translation pack if needed.
    func prepareLanguagePair(
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) async throws {
        guard source != target else { return }

        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)

        let availability = LanguageAvailability()
        let status = await availability.status(from: sourceLocale, to: targetLocale)

        switch status {
        case .installed:
            return
        case .supported:
            let session = TranslationSession(installedSource: sourceLocale, target: targetLocale)
            try await session.prepareTranslation()
            let key = "\(source.rawValue)->\(target.rawValue)"
            sessions[key] = session
        case .unsupported:
            // Try preparing two-hop through English
            if source != .english && target != .english {
                try await prepareLanguagePair(from: source, to: .english)
                try await prepareLanguagePair(from: .english, to: target)
            } else {
                throw TranslationError.unsupportedPair(source: source, target: target)
            }
        @unknown default:
            throw TranslationError.unsupportedPair(source: source, target: target)
        }
    }

    /// Checks the availability status of a language pair.
    func checkAvailability(
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) async -> LanguageAvailability.Status {
        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)
        let availability = LanguageAvailability()
        return await availability.status(from: sourceLocale, to: targetLocale)
    }

    /// Invalidates cached sessions (e.g., on language change).
    func invalidateSessions() {
        sessions.removeAll()
    }

    // MARK: - Private

    private func twoHopTranslate(
        text: String,
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) async throws -> String {
        // Source -> English
        let englishText = try await translate(text: text, from: source, to: .english)
        // English -> Target
        let finalText = try await translate(text: englishText, from: .english, to: target)
        return finalText
    }

    private func getOrCreateSession(
        key: String,
        from source: Locale.Language,
        to target: Locale.Language
    ) async throws -> TranslationSession {
        if let existing = sessions[key] {
            return existing
        }

        let session = TranslationSession(installedSource: source, target: target)
        sessions[key] = session
        return session
    }
}

enum TranslationError: LocalizedError {
    case unsupportedPair(source: SupportedLanguage, target: SupportedLanguage)
    case downloadFailed(language: SupportedLanguage)

    var errorDescription: String? {
        switch self {
        case .unsupportedPair(let source, let target):
            return "Translation from \(source.displayName) to \(target.displayName) is not supported."
        case .downloadFailed(let language):
            return "Failed to download translation pack for \(language.displayName)."
        }
    }
}
