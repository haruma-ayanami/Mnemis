import Testing
import Foundation
@testable import Mnemis

/// Все тесты, которые трогают `MockURLProtocol`, идут последовательно: обработчик общий.
@Suite(.serialized)
struct DictionaryProviderTests {
    private let baseURL = URL(string: "https://example.test/entries/en/")!

    private func provider() -> FreeDictionaryProvider {
        FreeDictionaryProvider(client: APIClient(session: MockURLProtocol.makeSession(), timeout: 5), baseURL: baseURL)
    }

    @Test func parsesSuccessfulResponse() async throws {
        MockURLProtocol.handler = { _ in MockURLProtocol.response(status: 200, body: Fixtures.freeDictionaryAccomplish) }

        let entry = try await provider().entry(for: "Accomplish")

        #expect(entry?.lemma == "accomplish")
        #expect(entry?.ipa == "/əˈkʌmplɪʃ/")
        #expect(entry?.definition == "to successfully complete something")
        #expect(entry?.examples == ["She accomplished her goal."])
        #expect(entry?.sourceID == "dictionaryapi.dev")
    }

    @Test func notFoundIsAnEmptyResultNotAnError() async throws {
        MockURLProtocol.handler = { _ in MockURLProtocol.response(status: 404) }

        #expect(try await provider().entry(for: "qwertyx") == nil)
    }

    @Test func serverErrorThrows() async {
        MockURLProtocol.handler = { _ in MockURLProtocol.response(status: 500) }

        await #expect(throws: APIError.httpStatus(500)) {
            try await provider().entry(for: "accomplish")
        }
    }

    @Test func timeoutIsMappedToTimeoutError() async {
        MockURLProtocol.handler = { _ in throw URLError(.timedOut) }

        await #expect(throws: APIError.timeout) {
            try await provider().entry(for: "accomplish")
        }
    }

    @Test func incompleteResponseStillParses() throws {
        let entry = try FreeDictionaryParser.parse(
            Data(Fixtures.freeDictionaryIncomplete.utf8),
            sourceID: "dictionaryapi.dev",
            licenseID: "dictionaryapi-dev"
        )

        #expect(entry?.lemma == "serendipity")
        #expect(entry?.ipa == nil)
        #expect(entry?.definition == nil)
        #expect(entry?.examples.isEmpty == true)
    }

    @Test func emptyArrayMeansNoEntry() throws {
        #expect(try FreeDictionaryParser.parse(Data("[]".utf8), sourceID: "x", licenseID: "y") == nil)
    }

    @Test func invalidJSONThrows() {
        #expect(throws: (any Error).self) {
            try FreeDictionaryParser.parse(Data("not json".utf8), sourceID: "x", licenseID: "y")
        }
    }

    @Test func lookupPrefersFirstProviderThatFindsTheWord() async {
        let found = Fixtures.entry()
        let service = DictionaryService(providers: [
            StubDictionaryProvider(sourceID: "local", entry: nil, error: nil),
            StubDictionaryProvider(sourceID: "api", entry: found, error: nil),
        ])

        #expect(await service.lookup("accomplish") == .found(found))
    }

    @Test func lookupReportsUnavailableWhenNetworkFails() async {
        let service = DictionaryService(providers: [
            StubDictionaryProvider(sourceID: "local", entry: nil, error: nil),
            StubDictionaryProvider(sourceID: "api", entry: nil, error: APIError.transport),
        ])

        #expect(await service.lookup("accomplish") == .unavailable)
    }

    @Test func lookupReportsNotFoundWhenNoSourceHasTheWord() async {
        let service = DictionaryService(providers: [
            StubDictionaryProvider(sourceID: "local", entry: nil, error: nil),
            StubDictionaryProvider(sourceID: "api", entry: nil, error: nil),
        ])

        #expect(await service.lookup("qwertyx") == .notFound)
    }
}
