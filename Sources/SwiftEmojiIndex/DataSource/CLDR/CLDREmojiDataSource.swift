import Foundation

/// Data source that fetches localized emoji data from Unicode CLDR.
///
/// CLDR (Common Locale Data Repository) provides emoji annotations
/// in 100+ languages, working on all platforms.
///
/// ## Usage
///
/// ```swift
/// // Japanese emoji names
/// let source = CLDREmojiDataSource(locale: Locale(identifier: "ja"))
/// let provider = EmojiIndexProvider(source: source)
///
/// // With Gemoji shortcodes
/// let blended = BlendedEmojiDataSource(
///     primary: CLDREmojiDataSource(locale: .current),
///     secondary: GemojiDataSource.shared
/// )
/// ```
///
/// ## Available Locales
///
/// See `CLDREmojiDataSource.availableLocales` for supported languages.
/// Data is fetched from GitHub's Unicode CLDR mirror.
public struct CLDREmojiDataSource: EmojiDataSource {
    public let identifier: String
    public let displayName: String
    public let locale: Locale

    /// Base URL for CLDR emoji annotations JSON.
    /// Uses the official Unicode CLDR JSON GitHub repository.
    private static let baseURL = "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-full/annotations"

    /// Creates a CLDR data source for the specified locale.
    ///
    /// - Parameter locale: The locale for emoji names. Falls back to English if unavailable.
    public init(locale: Locale = .current) {
        self.locale = locale
        self.identifier = "cldr-\(locale.identifier)"
        self.displayName = "Unicode CLDR (\(locale.identifier))"
    }

    /// Commonly available CLDR locales for emoji annotations.
    /// This is not exhaustive - CLDR supports 100+ locales.
    public static let availableLocales: [Locale] = [
        "af", "am", "ar", "as", "ast", "az", "be", "bg", "bn", "br",
        "bs", "ca", "ccp", "chr", "cs", "cy", "da", "de", "el", "en",
        "en-AU", "en-GB", "es", "es-419", "et", "eu", "fa", "fi", "fil",
        "fo", "fr", "fr-CA", "ga", "gd", "gl", "gu", "he", "hi", "hr",
        "hu", "hy", "ia", "id", "is", "it", "ja", "jv", "ka", "kk",
        "km", "kn", "ko", "kok", "ky", "lo", "lt", "lv", "mk", "ml",
        "mn", "mr", "ms", "my", "nb", "ne", "nl", "nn", "or", "pa",
        "pcm", "pl", "ps", "pt", "pt-PT", "ro", "ru", "sd", "si", "sk",
        "sl", "so", "sq", "sr", "sr-Latn", "sv", "sw", "ta", "te", "th",
        "tk", "to", "tr", "uk", "ur", "uz", "vi", "yue", "zh", "zh-Hant",
        "zu"
    ].map { Locale(identifier: $0) }

    public func fetch() async throws -> [EmojiRawEntry] {
        let localeId = bestAvailableLocale()
        let url = URL(string: "\(Self.baseURL)/\(localeId)/annotations.json")!

        let data: Data
        do {
            let (fetchedData, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmojiIndexError.invalidResponse(statusCode: 0)
            }
            guard httpResponse.statusCode == 200 else {
                throw EmojiIndexError.invalidResponse(statusCode: httpResponse.statusCode)
            }
            data = fetchedData
        } catch let error as EmojiIndexError {
            throw error
        } catch {
            throw EmojiIndexError.networkUnavailable(underlying: error)
        }

        return try parseAnnotations(data)
    }

    // MARK: - Private

    /// Find the best available locale, falling back as needed.
    private func bestAvailableLocale() -> String {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")

        // Try exact match
        if Self.availableLocales.contains(where: { $0.identifier == identifier }) {
            return identifier
        }

        // Try language only (e.g., "en-US" -> "en")
        if let language = locale.language.languageCode?.identifier {
            if Self.availableLocales.contains(where: { $0.identifier == language }) {
                return language
            }
        }

        // Fallback to English
        return "en"
    }

    /// Parse CLDR annotations JSON into emoji entries.
    private func parseAnnotations(_ data: Data) throws -> [EmojiRawEntry] {
        let json: CLDRAnnotationsRoot
        do {
            json = try JSONDecoder().decode(CLDRAnnotationsRoot.self, from: data)
        } catch {
            throw EmojiIndexError.decodingFailed(underlying: error)
        }

        var entries: [EmojiRawEntry] = []

        for (character, annotation) in json.annotations.annotations {
            // Skip skin tone variants
            guard !hasSkinToneModifier(character) else { continue }

            // tts is the main name, default is keywords
            let name = annotation.tts?.first ?? character
            let keywords = annotation.default ?? []

            entries.append(EmojiRawEntry(
                character: character,
                name: name,
                category: "Unknown", // CLDR doesn't provide categories
                shortcodes: [],       // Will be enriched by Gemoji
                keywords: keywords,
                supportsSkinTone: false // Will be enriched by Gemoji
            ))
        }

        return entries.sorted { $0.character < $1.character }
    }

    private func hasSkinToneModifier(_ emoji: String) -> Bool {
        let skinToneModifiers: Set<Unicode.Scalar> = [
            "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}"
        ]
        return emoji.unicodeScalars.contains { skinToneModifiers.contains($0) }
    }
}

// MARK: - CLDR JSON Models

private struct CLDRAnnotationsRoot: Decodable {
    let annotations: CLDRAnnotationsContainer

    struct CLDRAnnotationsContainer: Decodable {
        let annotations: [String: CLDRAnnotation]
    }
}

private struct CLDRAnnotation: Decodable {
    let `default`: [String]?
    let tts: [String]?
}
