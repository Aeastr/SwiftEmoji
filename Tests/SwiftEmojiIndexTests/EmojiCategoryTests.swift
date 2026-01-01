import Testing
@testable import SwiftEmojiIndex

@Suite("EmojiCategory")
struct EmojiCategoryTests {

    @Test("All 9 categories exist")
    func allCategoriesExist() {
        #expect(EmojiCategory.allCases.count == 9)
    }

    @Test("Each category has unique rawValue")
    func uniqueRawValues() {
        let rawValues = EmojiCategory.allCases.map(\.rawValue)
        let uniqueValues = Set(rawValues)
        #expect(rawValues.count == uniqueValues.count)
    }

    @Test("displayName returns rawValue")
    func displayName() {
        #expect(EmojiCategory.smileysAndEmotion.displayName == "Smileys & Emotion")
        #expect(EmojiCategory.peopleAndBody.displayName == "People & Body")
        #expect(EmojiCategory.animalsAndNature.displayName == "Animals & Nature")
        #expect(EmojiCategory.foodAndDrink.displayName == "Food & Drink")
        #expect(EmojiCategory.travelAndPlaces.displayName == "Travel & Places")
        #expect(EmojiCategory.activities.displayName == "Activities")
        #expect(EmojiCategory.objects.displayName == "Objects")
        #expect(EmojiCategory.symbols.displayName == "Symbols")
        #expect(EmojiCategory.flags.displayName == "Flags")
    }

    @Test("symbolName returns valid SF Symbol names", arguments: EmojiCategory.allCases)
    func symbolNames(category: EmojiCategory) {
        let symbolName = category.symbolName
        #expect(!symbolName.isEmpty)
        // Symbol names should not contain spaces
        #expect(!symbolName.contains(" "))
    }

    @Suite("from(gemojiCategory:)")
    struct GemojiCategoryMapping {
        @Test("Maps exact category names")
        func exactMatches() {
            #expect(EmojiCategory.from(gemojiCategory: "Smileys & Emotion") == .smileysAndEmotion)
            #expect(EmojiCategory.from(gemojiCategory: "People & Body") == .peopleAndBody)
            #expect(EmojiCategory.from(gemojiCategory: "Animals & Nature") == .animalsAndNature)
            #expect(EmojiCategory.from(gemojiCategory: "Food & Drink") == .foodAndDrink)
            #expect(EmojiCategory.from(gemojiCategory: "Travel & Places") == .travelAndPlaces)
            #expect(EmojiCategory.from(gemojiCategory: "Activities") == .activities)
            #expect(EmojiCategory.from(gemojiCategory: "Objects") == .objects)
            #expect(EmojiCategory.from(gemojiCategory: "Symbols") == .symbols)
            #expect(EmojiCategory.from(gemojiCategory: "Flags") == .flags)
        }

        @Test("Maps short category names")
        func shortNames() {
            #expect(EmojiCategory.from(gemojiCategory: "smileys") == .smileysAndEmotion)
            #expect(EmojiCategory.from(gemojiCategory: "people") == .peopleAndBody)
            #expect(EmojiCategory.from(gemojiCategory: "nature") == .animalsAndNature)
            #expect(EmojiCategory.from(gemojiCategory: "food") == .foodAndDrink)
            #expect(EmojiCategory.from(gemojiCategory: "travel") == .travelAndPlaces)
        }

        @Test("Case insensitive matching")
        func caseInsensitive() {
            #expect(EmojiCategory.from(gemojiCategory: "SMILEYS") == .smileysAndEmotion)
            #expect(EmojiCategory.from(gemojiCategory: "Flags") == .flags)
            #expect(EmojiCategory.from(gemojiCategory: "fLaGs") == .flags)
            #expect(EmojiCategory.from(gemojiCategory: "ACTIVITIES") == .activities)
        }

        @Test("Returns nil for unknown categories")
        func unknownCategory() {
            #expect(EmojiCategory.from(gemojiCategory: "unknown") == nil)
            #expect(EmojiCategory.from(gemojiCategory: "") == nil)
            #expect(EmojiCategory.from(gemojiCategory: "emotions") == nil)
        }
    }

    @Test("Identifiable id returns rawValue")
    func identifiableId() {
        #expect(EmojiCategory.smileysAndEmotion.id == "Smileys & Emotion")
        #expect(EmojiCategory.flags.id == "Flags")
    }

    @Test("Codable round-trip", arguments: EmojiCategory.allCases)
    func codable(category: EmojiCategory) throws {
        let data = try JSONEncoder().encode(category)
        let decoded = try JSONDecoder().decode(EmojiCategory.self, from: data)
        #expect(decoded == category)
    }
}
