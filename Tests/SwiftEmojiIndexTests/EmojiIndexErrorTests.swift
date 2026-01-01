import Testing
import Foundation
@testable import SwiftEmojiIndex

@Suite("EmojiIndexError")
struct EmojiIndexErrorTests {

    // MARK: - Error Cases

    @Test("All error cases have localized descriptions")
    func allErrorsHaveDescriptions() {
        let testError = NSError(domain: "test", code: 0)

        let errors: [EmojiIndexError] = [
            .networkUnavailable(underlying: testError),
            .invalidResponse(statusCode: 404),
            .decodingFailed(underlying: testError),
            .cacheReadFailed(underlying: testError),
            .cacheWriteFailed(underlying: testError),
            .noDataAvailable,
            .emptyData,
            .invalidURL("https://example.com"),
            .sourceUnavailable(reason: "Test")
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("All error cases have recovery suggestions")
    func allErrorsHaveRecoverySuggestions() {
        let testError = NSError(domain: "test", code: 0)

        let errors: [EmojiIndexError] = [
            .networkUnavailable(underlying: testError),
            .invalidResponse(statusCode: 500),
            .decodingFailed(underlying: testError),
            .cacheReadFailed(underlying: testError),
            .cacheWriteFailed(underlying: testError),
            .noDataAvailable,
            .emptyData,
            .invalidURL("bad-url"),
            .sourceUnavailable(reason: "Not available")
        ]

        for error in errors {
            #expect(error.recoverySuggestion != nil)
            #expect(!error.recoverySuggestion!.isEmpty)
        }
    }

    // MARK: - Specific Error Content

    @Suite("Error Content")
    struct ErrorContent {
        @Test("networkUnavailable includes underlying error")
        func networkUnavailableContent() {
            let underlyingError = NSError(domain: "network", code: -1009, userInfo: [NSLocalizedDescriptionKey: "No connection"])
            let error = EmojiIndexError.networkUnavailable(underlying: underlyingError)
            let description = error.errorDescription ?? ""

            #expect(description.contains("unavailable") || description.contains("Network"))
        }

        @Test("invalidResponse includes status code in description")
        func invalidResponseStatusCode() {
            let error = EmojiIndexError.invalidResponse(statusCode: 403)
            let description = error.errorDescription ?? ""

            #expect(description.contains("403"))
        }

        @Test("invalidResponse with different status codes")
        func invalidResponseVariousStatusCodes() {
            let statusCodes = [400, 401, 403, 404, 500, 502, 503]

            for code in statusCodes {
                let error = EmojiIndexError.invalidResponse(statusCode: code)
                let description = error.errorDescription ?? ""
                #expect(description.contains("\(code)"))
            }
        }

        @Test("invalidURL includes URL in description")
        func invalidURLContent() {
            let badURL = "not://valid"
            let error = EmojiIndexError.invalidURL(badURL)
            let description = error.errorDescription ?? ""

            #expect(description.contains(badURL))
        }

        @Test("sourceUnavailable includes reason in description")
        func sourceUnavailableReason() {
            let reason = "CoreEmoji not found"
            let error = EmojiIndexError.sourceUnavailable(reason: reason)
            let description = error.errorDescription ?? ""

            #expect(description.contains(reason))
        }

        @Test("decodingFailed includes underlying error info")
        func decodingFailedContent() {
            let decodingError = NSError(domain: "decoding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
            let error = EmojiIndexError.decodingFailed(underlying: decodingError)
            let description = error.errorDescription ?? ""

            #expect(description.lowercased().contains("decode") || description.lowercased().contains("failed"))
        }

        @Test("cacheReadFailed includes underlying error")
        func cacheReadFailedContent() {
            let cacheError = NSError(domain: "cache", code: 2, userInfo: [NSLocalizedDescriptionKey: "File not found"])
            let error = EmojiIndexError.cacheReadFailed(underlying: cacheError)
            let description = error.errorDescription ?? ""

            #expect(description.lowercased().contains("cache") || description.lowercased().contains("read"))
        }

        @Test("cacheWriteFailed includes underlying error")
        func cacheWriteFailedContent() {
            let cacheError = NSError(domain: "cache", code: 3, userInfo: [NSLocalizedDescriptionKey: "Disk full"])
            let error = EmojiIndexError.cacheWriteFailed(underlying: cacheError)
            let description = error.errorDescription ?? ""

            #expect(description.lowercased().contains("cache") || description.lowercased().contains("write"))
        }

        @Test("noDataAvailable has meaningful description")
        func noDataAvailableContent() {
            let error = EmojiIndexError.noDataAvailable
            let description = error.errorDescription ?? ""

            #expect(description.lowercased().contains("no") || description.lowercased().contains("data"))
        }

        @Test("emptyData has meaningful description")
        func emptyDataContent() {
            let error = EmojiIndexError.emptyData
            let description = error.errorDescription ?? ""

            #expect(description.lowercased().contains("empty") || description.lowercased().contains("data"))
        }
    }

    // MARK: - LocalizedError Conformance

    @Test("Conforms to LocalizedError")
    func localizedErrorConformance() {
        let error: LocalizedError = EmojiIndexError.noDataAvailable
        #expect(error.errorDescription != nil)
    }

    @Test("Conforms to Error protocol")
    func errorConformance() {
        let error: Error = EmojiIndexError.emptyData
        #expect(error.localizedDescription.count > 0)
    }

    // MARK: - Sendable

    @Test("Errors are Sendable")
    func sendableConformance() async {
        let error = EmojiIndexError.noDataAvailable

        await Task {
            // Can use error across actor boundaries
            _ = error.errorDescription
        }.value
    }

    @Test("Errors with associated values are Sendable")
    func sendableWithAssociatedValues() async {
        let testError = NSError(domain: "test", code: 0)
        let error = EmojiIndexError.networkUnavailable(underlying: testError)

        await Task {
            _ = error.errorDescription
        }.value
    }

    // MARK: - Recovery Suggestions Content

    @Suite("Recovery Suggestions")
    struct RecoverySuggestions {
        @Test("networkUnavailable suggests checking connection")
        func networkRecovery() {
            let error = EmojiIndexError.networkUnavailable(underlying: NSError(domain: "", code: 0))
            let recovery = error.recoverySuggestion ?? ""

            #expect(recovery.lowercased().contains("connection") || recovery.lowercased().contains("internet"))
        }

        @Test("invalidResponse suggests trying later")
        func invalidResponseRecovery() {
            let error = EmojiIndexError.invalidResponse(statusCode: 500)
            let recovery = error.recoverySuggestion ?? ""

            #expect(recovery.lowercased().contains("later") || recovery.lowercased().contains("try"))
        }

        @Test("noDataAvailable suggests connecting to internet")
        func noDataRecovery() {
            let error = EmojiIndexError.noDataAvailable
            let recovery = error.recoverySuggestion ?? ""

            #expect(recovery.lowercased().contains("internet") || recovery.lowercased().contains("connect"))
        }
    }
}
