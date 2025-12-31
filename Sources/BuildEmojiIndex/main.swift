/// BuildEmojiIndex - Interactive CLI to build offline fallback emoji indexes
///
/// Usage:
///   swift run BuildEmojiIndex
///
/// The CLI will guide you through options interactively.

import Foundation
import SwiftEmojiIndex

// MARK: - CLI Helpers

func printHeader(_ text: String) {
    print("\n\u{001B}[1m\(text)\u{001B}[0m")
    print(String(repeating: "─", count: 50))
}

func printOption(_ number: Int, _ text: String) {
    print("  \(number). \(text)")
}

func prompt(_ message: String) -> String {
    print("\n\(message) ", terminator: "")
    return readLine() ?? ""
}

func promptChoice(_ message: String, options: [String]) -> Int? {
    print("\n\(message)")
    for (i, option) in options.enumerated() {
        printOption(i + 1, option)
    }
    print()
    guard let input = readLine(), let choice = Int(input), choice >= 1, choice <= options.count else {
        return nil
    }
    return choice
}

func promptMultiChoice(_ message: String, options: [String]) -> [Int] {
    print("\n\(message)")
    for (i, option) in options.enumerated() {
        printOption(i + 1, option)
    }
    print("\nEnter numbers separated by spaces (e.g., '1 3 5'), or 'all': ", terminator: "")

    guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
        return []
    }

    if input.lowercased() == "all" {
        return Array(1...options.count)
    }

    return input.split(separator: " ").compactMap { Int($0) }.filter { $0 >= 1 && $0 <= options.count }
}

// MARK: - Data Structures

struct GemojiEntry: Decodable {
    let emoji: String
    let description: String
    let category: String
    let aliases: [String]
    let tags: [String]
    let skinTones: Bool?

    enum CodingKeys: String, CodingKey {
        case emoji, description, category, aliases, tags
        case skinTones = "skin_tones"
    }
}

struct CLDRAnnotationsRoot: Decodable {
    let annotations: CLDRAnnotationsContainer

    struct CLDRAnnotationsContainer: Decodable {
        let annotations: [String: CLDRAnnotation]
    }
}

struct CLDRAnnotation: Decodable {
    let `default`: [String]?
    let tts: [String]?
}

struct FallbackEntry: Codable {
    let character: String
    let name: String
    let category: String
    let shortcodes: [String]
    let keywords: [String]
    let supportsSkinTone: Bool
}

// MARK: - Sources

enum Source: String, CaseIterable {
    case gemoji = "GitHub Gemoji (English, with shortcodes)"
    case cldr = "Unicode CLDR (100+ languages)"
    case blended = "CLDR + Gemoji (localized names with shortcodes)"
    #if os(macOS)
    case apple = "Apple CoreEmoji (macOS, highest quality localization)"
    case appleBlended = "Apple CoreEmoji + Gemoji (macOS, localized with shortcodes)"
    #endif
}

let commonLocales = [
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "de": "German",
    "it": "Italian",
    "pt": "Portuguese",
    "ja": "Japanese",
    "ko": "Korean",
    "zh": "Chinese (Simplified)",
    "zh-Hant": "Chinese (Traditional)",
    "ar": "Arabic",
    "ru": "Russian",
    "hi": "Hindi",
    "th": "Thai",
    "vi": "Vietnamese",
    "id": "Indonesian",
    "ms": "Malay",
    "tr": "Turkish",
    "pl": "Polish",
    "nl": "Dutch",
    "sv": "Swedish",
    "da": "Danish",
    "fi": "Finnish",
    "no": "Norwegian",
    "uk": "Ukrainian",
    "cs": "Czech",
    "el": "Greek",
    "he": "Hebrew",
    "hu": "Hungarian",
    "ro": "Romanian"
]

// MARK: - Fetchers

func fetchGemoji() async throws -> [GemojiEntry] {
    let url = URL(string: "https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json")!
    print("  Fetching from GitHub Gemoji...")
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([GemojiEntry].self, from: data)
}

func fetchCLDR(locale: String) async throws -> [String: CLDRAnnotation] {
    let url = URL(string: "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-full/annotations/\(locale)/annotations.json")!
    print("  Fetching CLDR annotations for '\(locale)'...")
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw NSError(domain: "CLDR", code: 404, userInfo: [NSLocalizedDescriptionKey: "Locale '\(locale)' not found"])
    }

    let root = try JSONDecoder().decode(CLDRAnnotationsRoot.self, from: data)
    return root.annotations.annotations
}

#if os(macOS)
func fetchApple(locale: String) async throws -> [EmojiRawEntry] {
    print("  Fetching from Apple CoreEmoji for '\(locale)'...")

    guard AppleEmojiDataSource.isAvailable else {
        throw NSError(domain: "Apple", code: 1, userInfo: [NSLocalizedDescriptionKey: "CoreEmoji framework not available"])
    }

    let source = AppleEmojiDataSource(locale: Locale(identifier: locale))
    return try await source.fetch()
}

func appleAvailableLocales() -> [String: String] {
    guard AppleEmojiDataSource.isAvailable else { return [:] }

    var result: [String: String] = [:]
    for locale in AppleEmojiDataSource.availableLocales() {
        let name = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        result[locale.identifier] = name
    }
    return result
}
#endif

// MARK: - Builders

func buildFromGemoji(_ entries: [GemojiEntry]) -> [FallbackEntry] {
    entries.map { entry in
        let descriptionWords = entry.description
            .lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        let allKeywords = Set(descriptionWords + entry.aliases + entry.tags).sorted()

        return FallbackEntry(
            character: entry.emoji,
            name: entry.description,
            category: entry.category,
            shortcodes: entry.aliases,
            keywords: allKeywords,
            supportsSkinTone: entry.skinTones ?? false
        )
    }
}

#if os(macOS)
func buildFromApple(_ entries: [EmojiRawEntry], gemojiEntries: [GemojiEntry]?) -> [FallbackEntry] {
    // Index gemoji by character for enrichment (categories, shortcodes, etc.)
    var gemojiByChar: [String: GemojiEntry] = [:]
    if let gemoji = gemojiEntries {
        for entry in gemoji {
            gemojiByChar[entry.emoji] = entry
        }
    }

    return entries.map { entry in
        let gemoji = gemojiByChar[entry.character]

        return FallbackEntry(
            character: entry.character,
            name: entry.name,
            category: gemoji?.category ?? entry.category,  // Get category from Gemoji
            shortcodes: gemoji?.aliases ?? entry.shortcodes,
            keywords: Array(Set(entry.keywords + (gemoji?.tags ?? []))),
            supportsSkinTone: gemoji?.skinTones ?? entry.supportsSkinTone
        )
    }
}
#endif

func buildFromCLDR(_ annotations: [String: CLDRAnnotation], gemojiEntries: [GemojiEntry]?) -> [FallbackEntry] {
    // Index gemoji by character for enrichment
    var gemojiByChar: [String: GemojiEntry] = [:]
    if let gemoji = gemojiEntries {
        for entry in gemoji {
            gemojiByChar[entry.emoji] = entry
        }
    }

    let skinToneModifiers: Set<Unicode.Scalar> = [
        "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}"
    ]

    var entries: [FallbackEntry] = []

    for (character, annotation) in annotations {
        // Skip skin tone variants
        if character.unicodeScalars.contains(where: { skinToneModifiers.contains($0) }) {
            continue
        }

        let name = annotation.tts?.first ?? character
        let keywords = annotation.default ?? []

        // Enrich with Gemoji data if available
        let gemoji = gemojiByChar[character]

        entries.append(FallbackEntry(
            character: character,
            name: name,
            category: gemoji?.category ?? "Unknown",
            shortcodes: gemoji?.aliases ?? [],
            keywords: Array(Set(keywords + (gemoji?.tags ?? []))),
            supportsSkinTone: gemoji?.skinTones ?? false
        ))
    }

    return entries.sorted { $0.character < $1.character }
}

func findPackageRoot(sourceFile: String = #file) -> URL? {
    let fm = FileManager.default

    // Try 1: Walk up from source file location (works in Xcode)
    var current = URL(fileURLWithPath: sourceFile).deletingLastPathComponent()
    for _ in 0..<10 {
        let packageSwift = current.appendingPathComponent("Package.swift")
        if fm.fileExists(atPath: packageSwift.path) {
            return current
        }
        current = current.deletingLastPathComponent()
    }

    // Try 2: Walk up from current working directory (works in terminal)
    current = URL(fileURLWithPath: fm.currentDirectoryPath)
    for _ in 0..<10 {
        let packageSwift = current.appendingPathComponent("Package.swift")
        if fm.fileExists(atPath: packageSwift.path) {
            return current
        }
        current = current.deletingLastPathComponent()
    }

    return nil
}

func writeOutput(_ entries: [FallbackEntry], locale: String?) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(entries)

    let filename: String
    if let locale = locale, locale != "en" {
        filename = "emoji-fallback-\(locale).json"
    } else {
        filename = "emoji-fallback.json"
    }

    guard let packageRoot = findPackageRoot() else {
        throw NSError(domain: "CLI", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not find package root (Package.swift). Run from package directory."
        ])
    }

    let resourcesDir = packageRoot.appendingPathComponent("Sources/SwiftEmojiIndex/Resources")
    let fm = FileManager.default

    // Create Resources directory if it doesn't exist
    if !fm.fileExists(atPath: resourcesDir.path) {
        try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
    }

    let outputURL = resourcesDir.appendingPathComponent(filename)
    try data.write(to: outputURL, options: .atomic)

    print("  ✓ Written \(entries.count) entries to \(filename)")
    print("    Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
}

// MARK: - Main

func run() async throws {
    print("\n🎨 BuildEmojiIndex")
    print("═══════════════════════════════════════════════════")
    print("Build offline fallback emoji data for SwiftEmojiIndex")

    // Step 1: Choose source
    printHeader("Choose Data Source")

    guard let sourceChoice = promptChoice("Which source would you like to use?", options: Source.allCases.map(\.rawValue)) else {
        print("Invalid choice. Exiting.")
        return
    }

    let source = Source.allCases[sourceChoice - 1]

    switch source {
    case .gemoji:
        // Build from Gemoji only
        printHeader("Building from Gemoji")
        let gemoji = try await fetchGemoji()
        let entries = buildFromGemoji(gemoji)
        try writeOutput(entries, locale: nil)

    case .cldr:
        // Build from CLDR only (no shortcodes)
        printHeader("Select Locales")

        let localeOptions = commonLocales.map { "\($0.value) (\($0.key))" }
        let choices = promptMultiChoice("Which locales do you want to build?", options: localeOptions)

        if choices.isEmpty {
            print("No locales selected. Exiting.")
            return
        }

        let localeKeys = Array(commonLocales.keys.sorted())
        let selectedLocales = choices.map { localeKeys[$0 - 1] }

        printHeader("Building from CLDR")

        for locale in selectedLocales {
            print("\n[\(locale)]")
            do {
                let annotations = try await fetchCLDR(locale: locale)
                let entries = buildFromCLDR(annotations, gemojiEntries: nil)
                try writeOutput(entries, locale: locale)
            } catch {
                print("  ✗ Failed: \(error.localizedDescription)")
            }
        }

    case .blended:
        // Build from CLDR + Gemoji (best of both)
        printHeader("Select Locales")

        let localeOptions = commonLocales.map { "\($0.value) (\($0.key))" }
        let choices = promptMultiChoice("Which locales do you want to build?", options: localeOptions)

        if choices.isEmpty {
            print("No locales selected. Exiting.")
            return
        }

        let localeKeys = Array(commonLocales.keys.sorted())
        let selectedLocales = choices.map { localeKeys[$0 - 1] }

        printHeader("Building Blended (CLDR + Gemoji)")

        // Fetch Gemoji once for enrichment
        print("\n[Fetching Gemoji for shortcodes...]")
        let gemoji = try await fetchGemoji()
        print("  ✓ Loaded \(gemoji.count) Gemoji entries")

        for locale in selectedLocales {
            print("\n[\(locale)]")
            do {
                let annotations = try await fetchCLDR(locale: locale)
                let entries = buildFromCLDR(annotations, gemojiEntries: gemoji)
                try writeOutput(entries, locale: locale)
            } catch {
                print("  ✗ Failed: \(error.localizedDescription)")
            }
        }

    #if os(macOS)
    case .apple:
        // Build from Apple CoreEmoji only
        guard AppleEmojiDataSource.isAvailable else {
            print("\n✗ Apple CoreEmoji is not available on this system.")
            return
        }

        printHeader("Select Locales")

        let appleLocales = appleAvailableLocales()
        if appleLocales.isEmpty {
            print("No Apple locales available. Exiting.")
            return
        }

        let sortedKeys = appleLocales.keys.sorted()
        let localeOptions = sortedKeys.map { "\(appleLocales[$0]!) (\($0))" }
        let choices = promptMultiChoice("Which locales do you want to build?", options: localeOptions)

        if choices.isEmpty {
            print("No locales selected. Exiting.")
            return
        }

        let selectedLocales = choices.map { sortedKeys[$0 - 1] }

        printHeader("Building from Apple CoreEmoji")

        for locale in selectedLocales {
            print("\n[\(locale)]")
            do {
                let appleEntries = try await fetchApple(locale: locale)
                let entries = buildFromApple(appleEntries, gemojiEntries: nil)
                try writeOutput(entries, locale: locale)
            } catch {
                print("  ✗ Failed: \(error.localizedDescription)")
            }
        }

    case .appleBlended:
        // Build from Apple CoreEmoji + Gemoji
        guard AppleEmojiDataSource.isAvailable else {
            print("\n✗ Apple CoreEmoji is not available on this system.")
            return
        }

        printHeader("Select Locales")

        let appleLocales = appleAvailableLocales()
        if appleLocales.isEmpty {
            print("No Apple locales available. Exiting.")
            return
        }

        let sortedKeys = appleLocales.keys.sorted()
        let localeOptions = sortedKeys.map { "\(appleLocales[$0]!) (\($0))" }
        let choices = promptMultiChoice("Which locales do you want to build?", options: localeOptions)

        if choices.isEmpty {
            print("No locales selected. Exiting.")
            return
        }

        let selectedLocales = choices.map { sortedKeys[$0 - 1] }

        printHeader("Building Blended (Apple CoreEmoji + Gemoji)")

        // Fetch Gemoji once for enrichment
        print("\n[Fetching Gemoji for shortcodes...]")
        let gemoji = try await fetchGemoji()
        print("  ✓ Loaded \(gemoji.count) Gemoji entries")

        for locale in selectedLocales {
            print("\n[\(locale)]")
            do {
                let appleEntries = try await fetchApple(locale: locale)
                let entries = buildFromApple(appleEntries, gemojiEntries: gemoji)
                try writeOutput(entries, locale: locale)
            } catch {
                print("  ✗ Failed: \(error.localizedDescription)")
            }
        }
    #endif
    }

    printHeader("Done!")
    print("Run your app to use the new fallback data.\n")
}

// Entry point
try await run()
