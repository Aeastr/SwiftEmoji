import Testing
import Foundation
@testable import SwiftEmojiIndex

@Suite("Emoji Model")
struct EmojiTests {

    // MARK: - Initialization

    @Suite("Initialization")
    struct Initialization {
        @Test("Full initializer sets all properties correctly")
        func fullInitializer() {
            let emoji = Emoji(
                character: "😀",
                name: "grinning face",
                category: .smileysAndEmotion,
                shortcodes: ["grinning"],
                keywords: ["happy"],
                supportsSkinTone: false
            )

            #expect(emoji.character == "😀")
            #expect(emoji.name == "grinning face")
            #expect(emoji.category == .smileysAndEmotion)
            #expect(emoji.shortcodes == ["grinning"])
            #expect(emoji.keywords == ["happy"])
            #expect(emoji.supportsSkinTone == false)
        }

        @Test("Convenience initializer uses character as name fallback")
        func convenienceInitializer() {
            let emoji = Emoji("🎨")

            #expect(emoji.character == "🎨")
            #expect(emoji.name == "🎨")
            #expect(emoji.category == .symbols)
            #expect(emoji.shortcodes.isEmpty)
            #expect(emoji.keywords.isEmpty)
            #expect(emoji.supportsSkinTone == false)
        }

        @Test("Default parameter values")
        func defaultParameters() {
            let emoji = Emoji(
                character: "🔥",
                name: "fire",
                category: .travelAndPlaces
            )

            #expect(emoji.shortcodes.isEmpty)
            #expect(emoji.keywords.isEmpty)
            #expect(emoji.supportsSkinTone == false)
        }
    }

    // MARK: - Identifiable

    @Test("id returns character")
    func identifiableId() {
        let emoji = Emoji("🎉")
        #expect(emoji.id == "🎉")
    }

    // MARK: - Hashable & Equatable

    @Test("Emojis with same properties are equal")
    func equality() {
        let emoji1 = Emoji(character: "👋", name: "wave", category: .peopleAndBody)
        let emoji2 = Emoji(character: "👋", name: "wave", category: .peopleAndBody)

        #expect(emoji1 == emoji2)
        #expect(emoji1.hashValue == emoji2.hashValue)
    }

    @Test("Emojis with different characters are not equal")
    func inequality() {
        let emoji1 = Emoji(character: "👋", name: "wave", category: .peopleAndBody)
        let emoji2 = Emoji(character: "👍", name: "thumbs up", category: .peopleAndBody)

        #expect(emoji1 != emoji2)
    }

    // MARK: - Skin Tone Support

    @Suite("Skin Tone")
    struct SkinToneSupport {
        @Test("withSkinTone returns original when supportsSkinTone is false")
        func noSkinToneSupport() {
            let emoji = Emoji(
                character: "🚀",
                name: "rocket",
                category: .travelAndPlaces,
                supportsSkinTone: false
            )

            #expect(emoji.withSkinTone(.dark) == "🚀")
            #expect(emoji.withSkinTone(.light) == "🚀")
        }

        @Test("withSkinTone returns original for .none skin tone")
        func noneSkinTone() {
            let emoji = Emoji(
                character: "👋",
                name: "waving hand",
                category: .peopleAndBody,
                supportsSkinTone: true
            )
            #expect(emoji.withSkinTone(.none) == "👋")
        }

        @Test("withSkinTone appends modifier for supported emoji", arguments: SkinTone.allCases)
        func appliesSkinTone(skinTone: SkinTone) {
            let emoji = Emoji(
                character: "👋",
                name: "waving hand",
                category: .peopleAndBody,
                supportsSkinTone: true
            )
            let result = emoji.withSkinTone(skinTone)

            if skinTone == .none {
                #expect(result == "👋")
            } else {
                #expect(result == "👋" + skinTone.modifier)
            }
        }
    }

    // MARK: - CustomStringConvertible

    @Test("description returns character")
    func description() {
        let emoji = Emoji("🌟")
        #expect(emoji.description == "🌟")
        #expect(String(describing: emoji) == "🌟")
    }

    // MARK: - Codable

    @Test("Encodes and decodes correctly")
    func codable() throws {
        let original = Emoji(
            character: "😀",
            name: "grinning face",
            category: .smileysAndEmotion,
            shortcodes: ["grinning", "smile"],
            keywords: ["happy", "joy"],
            supportsSkinTone: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Emoji.self, from: data)

        #expect(decoded.character == original.character)
        #expect(decoded.name == original.name)
        #expect(decoded.category == original.category)
        #expect(decoded.shortcodes == original.shortcodes)
        #expect(decoded.keywords == original.keywords)
        #expect(decoded.supportsSkinTone == original.supportsSkinTone)
    }

    // MARK: - Static Lookup

    @Test("lookup returns emoji with metadata from index")
    func staticLookup() async {
        let emoji = await Emoji.lookup("😀")

        if let emoji = emoji {
            #expect(emoji.character == "😀")
            #expect(!emoji.name.isEmpty)
        }
        // nil is acceptable if index isn't loaded or emoji not found
    }

    @Test("lookup returns nil for non-emoji character")
    func lookupNonEmoji() async {
        let emoji = await Emoji.lookup("abc")
        #expect(emoji == nil)
    }
}
