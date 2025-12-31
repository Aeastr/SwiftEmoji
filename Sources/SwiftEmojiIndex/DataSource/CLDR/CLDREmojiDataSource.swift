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
    private static let baseURL = "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-full/annotations"

    /// GitHub API URL to list available annotation directories.
    private static let apiURL = "https://api.github.com/repos/unicode-org/cldr-json/contents/cldr-json/cldr-annotations-full/annotations"

    /// Actor to manage cached locales with thread safety.
    private actor LocalesCache {
        static let shared = LocalesCache()

        private var cachedLocales: [Locale]?
        private var cacheDate: Date?
        private let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

        func getCached() -> [Locale]? {
            guard let cached = cachedLocales,
                  let date = cacheDate,
                  Date().timeIntervalSince(date) < maxAge else {
                return nil
            }
            return cached
        }

        func setCached(_ locales: [Locale]) {
            cachedLocales = locales
            cacheDate = Date()
        }

        func currentCached() -> [Locale]? {
            cachedLocales
        }
    }

    /// Creates a CLDR data source for the specified locale.
    ///
    /// - Parameter locale: The locale for emoji names. Falls back to English if unavailable.
    public init(locale: Locale = .current) {
        self.locale = locale
        self.identifier = "cldr-\(locale.identifier)"
        self.displayName = "Unicode CLDR (\(locale.identifier))"
    }

    /// Fetches available CLDR locales from the repository.
    ///
    /// Results are cached for 7 days. Falls back to common locales on error.
    public static func fetchAvailableLocales() async -> [Locale] {
        // Check cache
        if let cached = await LocalesCache.shared.getCached() {
            return cached
        }

        do {
            let locales = try await fetchLocalesFromAPI()
            await LocalesCache.shared.setCached(locales)
            return locales
        } catch {
            // Fall back to common locales
            return fallbackLocales
        }
    }

    /// Synchronous access to cached locales (may be empty if not fetched yet).
    /// For fresh data, use `fetchAvailableLocales()`.
    public static var availableLocales: [Locale] {
        // Note: This is a best-effort sync access. Use fetchAvailableLocales() for guaranteed fresh data.
        fallbackLocales
    }

    /// Common locales as fallback when API fetch fails.
    private static let fallbackLocales: [Locale] = [
        "en", "es", "fr", "de", "it", "pt", "ja", "ko", "zh", "zh-Hant",
        "ar", "ru", "hi", "th", "vi", "id", "ms", "tr", "pl", "nl"
    ].map { Locale(identifier: $0) }

    private static func fetchLocalesFromAPI() async throws -> [Locale] {
        guard let url = URL(string: apiURL) else {
            throw EmojiIndexError.invalidURL(apiURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EmojiIndexError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let items = try JSONDecoder().decode([GitHubContentItem].self, from: data)

        return items
            .filter { $0.type == "dir" }
            .map { Locale(identifier: $0.name) }
            .sorted { $0.identifier < $1.identifier }
    }

    public func fetch() async throws -> [EmojiRawEntry] {
        let localeId = bestAvailableLocale()
        #if DEBUG
        print("[CLDREmojiDataSource] Requested locale: \(locale.identifier), resolved to: \(localeId)")
        #endif

        // Try requested locale first, fall back to English if not found
        var data = try await fetchAnnotations(for: localeId)
        if data == nil && localeId != "en" {
            data = try await fetchAnnotations(for: "en")
        }

        guard let data else {
            throw EmojiIndexError.sourceUnavailable(reason: "Could not fetch CLDR annotations for \(localeId) or en")
        }

        let entries = try parseAnnotations(data)
        #if DEBUG
        if let first = entries.first {
            print("[CLDREmojiDataSource] First emoji: \(first.character) = \"\(first.name)\"")
        }
        print("[CLDREmojiDataSource] Fetched \(entries.count) entries")
        #endif
        return entries
    }

    /// Fetch annotations for a specific locale, returns nil if not found (404).
    private func fetchAnnotations(for localeId: String) async throws -> Data? {
        let url = URL(string: "\(Self.baseURL)/\(localeId)/annotations.json")!

        let (fetchedData, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmojiIndexError.invalidResponse(statusCode: 0)
        }

        // 404 = locale not available, return nil to try fallback
        if httpResponse.statusCode == 404 {
            #if DEBUG
            print("[CLDREmojiDataSource] Locale '\(localeId)' not found (404), will try fallback")
            #endif
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw EmojiIndexError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        return fetchedData
    }

    // MARK: - Private

    /// Get the locale identifier to use for fetching.
    /// Returns the language code (e.g., "en" from "en_US").
    private func bestAvailableLocale() -> String {
        // Use language code directly - CLDR directories are language codes
        if let language = locale.language.languageCode?.identifier {
            return language
        }
        // Fallback: clean up identifier
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        return identifier.components(separatedBy: "-").first ?? "en"
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

// MARK: - JSON Models

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

private struct GitHubContentItem: Decodable {
    let name: String
    let type: String // "dir" or "file"
}
