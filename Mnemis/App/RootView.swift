import SwiftUI

/// Главная навигация: пять разделов из ABOUT.md, раздел 15.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                TodayView()
            }
            Tab("Learn", systemImage: "rectangle.stack") {
                LearnView()
            }
            Tab("Words", systemImage: "character.book.closed") {
                WordsView()
            }
            Tab("Statistics", systemImage: "chart.bar") {
                StatisticsView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}
