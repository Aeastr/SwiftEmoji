import Testing
import Foundation
@testable import SwiftEmojiIndex

@Suite("SkinTone")
struct SkinToneTests {

    @Test("All 6 skin tones exist")
    func allSkinTonesExist() {
        #expect(SkinTone.allCases.count == 6)
    }

    @Test("Skin tones are in expected order")
    func skinToneOrder() {
        let expected: [SkinTone] = [.none, .light, .mediumLight, .medium, .mediumDark, .dark]
        #expect(SkinTone.allCases == expected)
    }

    @Suite("modifier")
    struct Modifier {
        @Test(".none returns empty string")
        func noneModifier() {
            #expect(SkinTone.none.modifier == "")
        }

        @Test("Each skin tone has unique non-empty modifier", arguments: SkinTone.allCases.filter { $0 != .none })
        func uniqueModifiers(skinTone: SkinTone) {
            let modifier = skinTone.modifier
            #expect(!modifier.isEmpty)
        }

        @Test("Modifiers are correct Unicode Fitzpatrick scale values")
        func correctUnicodeValues() {
            #expect(SkinTone.light.modifier == "\u{1F3FB}")
            #expect(SkinTone.mediumLight.modifier == "\u{1F3FC}")
            #expect(SkinTone.medium.modifier == "\u{1F3FD}")
            #expect(SkinTone.mediumDark.modifier == "\u{1F3FE}")
            #expect(SkinTone.dark.modifier == "\u{1F3FF}")
        }

        @Test("All modifiers are unique")
        func allModifiersUnique() {
            let modifiers = SkinTone.allCases.filter { $0 != .none }.map(\.modifier)
            let uniqueModifiers = Set(modifiers)
            #expect(modifiers.count == uniqueModifiers.count)
        }
    }

    @Suite("displayName")
    struct DisplayName {
        @Test("All skin tones have non-empty display names", arguments: SkinTone.allCases)
        func nonEmptyDisplayNames(skinTone: SkinTone) {
            #expect(!skinTone.displayName.isEmpty)
        }

        @Test("Expected display name values")
        func expectedValues() {
            #expect(SkinTone.none.displayName == "Default")
            #expect(SkinTone.light.displayName == "Light")
            #expect(SkinTone.mediumLight.displayName == "Medium-Light")
            #expect(SkinTone.medium.displayName == "Medium")
            #expect(SkinTone.mediumDark.displayName == "Medium-Dark")
            #expect(SkinTone.dark.displayName == "Dark")
        }
    }

    @Suite("example")
    struct Example {
        @Test("Example is raised hand with modifier")
        func exampleFormat() {
            #expect(SkinTone.none.example == "✋")
            #expect(SkinTone.light.example == "✋\u{1F3FB}")
            #expect(SkinTone.mediumLight.example == "✋\u{1F3FC}")
            #expect(SkinTone.medium.example == "✋\u{1F3FD}")
            #expect(SkinTone.mediumDark.example == "✋\u{1F3FE}")
            #expect(SkinTone.dark.example == "✋\u{1F3FF}")
        }

        @Test("All examples contain raised hand base", arguments: SkinTone.allCases)
        func containsBaseEmoji(skinTone: SkinTone) {
            #expect(skinTone.example.hasPrefix("✋"))
        }
    }

    @Test("Identifiable id returns rawValue")
    func identifiableId() {
        #expect(SkinTone.none.id == "none")
        #expect(SkinTone.light.id == "light")
        #expect(SkinTone.mediumLight.id == "mediumLight")
        #expect(SkinTone.medium.id == "medium")
        #expect(SkinTone.mediumDark.id == "mediumDark")
        #expect(SkinTone.dark.id == "dark")
    }

    @Test("Codable round-trip", arguments: SkinTone.allCases)
    func codable(skinTone: SkinTone) throws {
        let data = try JSONEncoder().encode(skinTone)
        let decoded = try JSONDecoder().decode(SkinTone.self, from: data)
        #expect(decoded == skinTone)
    }
}
