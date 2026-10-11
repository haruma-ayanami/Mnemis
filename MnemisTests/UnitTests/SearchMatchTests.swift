import Foundation
import Testing
@testable import Mnemis

/// Подпись совпадения справа в результатах поиска: точное, начало, вхождение, заметка, перевод, значение.
@MainActor
struct SearchMatchTests {
    private func word(_ lemma: String, translation: String = "", definition: String? = nil, note: String? = nil) -> Word {
        var word = Word(lemma: lemma, translation: translation, definition: definition, origin: .builtin, createdAt: Date(timeIntervalSince1970: 0))
        word.userNote = note
        return word
    }

    @Test func exactMatchIgnoresCaseAndSpaces() {
        #expect(WordsViewModel.match(of: word("achieve"), query: "  ACHIEVE ") == .exact)
    }

    @Test func startsWithIsNamedBeforeContains() {
        #expect(WordsViewModel.match(of: word("achievement"), query: "achieve") == .startsWith)
        #expect(WordsViewModel.match(of: word("unachieved"), query: "achieve") == .contains)
    }

    @Test func noteAndTranslationAreNamed() {
        #expect(WordsViewModel.match(of: word("accomplish", translation: "выполнять", note: "achieve in note"), query: "achieve") == .note)
        #expect(WordsViewModel.match(of: word("achieve", translation: "добиваться"), query: "добиваться") == .translation)
    }

    @Test func meaningIsTheFallback() {
        #expect(WordsViewModel.match(of: word("accomplish", definition: "to achieve something"), query: "achieve") == .meaning)
    }

    @Test func emptyQueryHasNoMatch() {
        #expect(WordsViewModel.match(of: word("achieve"), query: "   ") == nil)
    }
}
