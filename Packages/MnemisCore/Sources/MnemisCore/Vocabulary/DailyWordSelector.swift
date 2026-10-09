import Foundation

/// Чистый выбор слова дня (ABOUT.md, раздел 5).
/// Один и тот же день всегда даёт одно и то же слово, поэтому Daily Word стабилен в течение дня.
public enum DailyWordSelector {
    /// - Parameters:
    ///   - dayKey: ключ дня, например `2026-10-08`.
    ///   - candidates: слова, из которых выбираем.
    ///   - excluded: id слов, которые уже освоены или отмечены как известные.
    ///   - preferredLevel: уровень пользователя. Если подходящих слов нет, берём любой уровень.
    public static func select(
        dayKey: String,
        candidates: [Word],
        excluded: Set<UUID>,
        preferredLevel: String? = nil
    ) -> Word? {
        let eligible = candidates
            .filter { !excluded.contains($0.id) }
            .sorted { lhs, rhs in
                // Более частотные слова первыми, при равенстве — по алфавиту.
                (lhs.frequency ?? .max, lhs.lemma) < (rhs.frequency ?? .max, rhs.lemma)
            }

        let leveled = preferredLevel.map { level in eligible.filter { $0.level == level } } ?? []
        let pool = leveled.isEmpty ? eligible : leveled
        guard !pool.isEmpty else { return nil }

        let index = Int(fnv1a(dayKey) % UInt64(pool.count))
        return pool[index]
    }

    /// Стабильный хеш (FNV-1a). `Hasher` в Swift не подходит: его результат меняется между запусками.
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
