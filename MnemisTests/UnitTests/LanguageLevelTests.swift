import Testing
@testable import Mnemis

/// Шкала CEFR A1–C1 и чтение сохранённых уровней (ABOUT.md, раздел 13).
struct LanguageLevelTests {
    @Test func scaleRunsFromA1ToC1() {
        #expect(LanguageLevel.allCases.map(\.rawValue) == ["A1", "A2", "B1", "B2", "C1"])
    }

    @Test func nextLevelFollowsTheScale() {
        #expect(LanguageLevel.a1.next == .a2)
        #expect(LanguageLevel.b2.next == .c1)
        #expect(LanguageLevel.c1.next == nil)
    }

    @Test func legacyIELTSValueReadsAsB1() {
        #expect(LanguageLevel.stored("IELTS") == .b1)
        #expect(LanguageLevel.stored("C1") == .c1)
    }
}
