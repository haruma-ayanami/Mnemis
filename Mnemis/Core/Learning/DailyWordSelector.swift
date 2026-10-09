import Foundation

/// Чистый выбор слова дня (ARCHITECTURE.md, раздел 6). Одинаковый вход — одинаковый результат.
enum DailyWordSelector {
    /// - Parameters:
    ///   - dayID: локальный день, например `2026-10-08`. От него зависит выбор.
    ///   - candidates: все слова словаря.
    ///   - progress: прогресс пользователя, чтобы исключить освоенные слова.
    ///   - previouslyAssigned: слова, которые уже выпадали как Daily Word.
    ///   - preferredLevel: уровень пользователя. Если подходящих слов нет, берём любой уровень.
    /// - Returns: `nil`, если подходящих слов не осталось (словарь исчерпан).
    static func select(
        dayID: String,
        candidates: [Word],
        progress: [WordProgress],
        previouslyAssigned: Set<UUID>,
        preferredLevel: String? = nil
    ) -> Word? {
        let masteredIDs = Set(progress.filter { $0.status == .known || $0.status == .remembered || $0.status == .suspended }.map(\.wordID))
        let eligible = candidates
            .filter { $0.origin != .api }
            .filter { !masteredIDs.contains($0.id) && !previouslyAssigned.contains($0.id) }
            .sorted { lhs, rhs in
                // Частотные слова первыми, при равенстве — по алфавиту: порядок стабилен.
                (lhs.frequencyRank ?? .max, lhs.lemma) < (rhs.frequencyRank ?? .max, rhs.lemma)
            }

        let leveled = preferredLevel.map { level in eligible.filter { $0.level == level } } ?? []
        let pool = leveled.isEmpty ? eligible : leveled
        guard !pool.isEmpty else { return nil }

        return pool[Int(fnv1a(dayID) % UInt64(pool.count))]
    }

    /// Стабильный хеш FNV-1a. `Hasher` не подходит: его результат меняется между запусками.
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
