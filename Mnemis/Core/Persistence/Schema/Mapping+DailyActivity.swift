import Foundation

// Маппинг сводки активности. Отдельный файл: модель небольшая и не связана с основным маппингом слов.

extension DailyActivityEntity {
    func apply(_ activity: DailyActivity) {
        localDayID = activity.localDayID
        dayStart = activity.dayStart
        reviewCount = activity.reviewCount
        correctCount = activity.correctCount
    }

    var domain: DailyActivity {
        DailyActivity(
            localDayID: localDayID,
            dayStart: dayStart,
            reviewCount: reviewCount,
            correctCount: correctCount
        )
    }
}
