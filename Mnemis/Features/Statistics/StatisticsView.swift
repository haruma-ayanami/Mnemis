import SwiftUI

/// Статистика (ABOUT.md, раздел 15): простые и полезные числа, а не декоративные графики.
struct StatisticsView: View {
    @State private var viewModel: StatisticsViewModel
    @Namespace private var pill

    init(container: AppContainer) {
        _viewModel = State(initialValue: StatisticsViewModel(container: container))
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            switch viewModel.state {
            case .loading: LoadingView()
            case .failed(let message): ErrorStateView(message: message)
            case .loaded: content
            }
        }
        .onAppear { viewModel.load() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Statistics").font(.mnemisTitle).tracking(-0.8).foregroundStyle(AppColor.ink)
                    .padding(.top, 8)

                periodPicker
                headline.screenEntrance(delay: 0.04)
                heatmap.screenEntrance(delay: 0.08)

                HStack(spacing: 10) {
                    StatTile(title: "streak · longest", text: "\(viewModel.currentStreak)", secondary: " / \(viewModel.longestStreak)")
                    StatTile(title: "reviews", text: viewModel.reviewCount.formatted())
                    StatTile(title: "level", text: viewModel.cefrLevel.rawValue, secondary: " · \(viewModel.cefrPercent)%")
                }
                .screenEntrance(delay: 0.12)

                distribution.screenEntrance(delay: 0.16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(StatsPeriod.allCases) { period in
                Button { withAnimation(Motion.swap) { viewModel.period = period } } label: {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(viewModel.period == period ? AppColor.ink : AppColor.ash)
                        .background {
                            if viewModel.period == period {
                                Capsule().fill(AppColor.hairline).matchedGeometryEffect(id: "period-pill", in: pill)
                            }
                        }
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(viewModel.period == period ? [.isSelected] : [])
            }
        }
        .padding(4)
        .glassCapsule()
    }

    private var headline: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%03d", viewModel.learned))
                    .font(.mnemisCounterLarge).tracking(-2.8)
                    .foregroundStyle(AppColor.ink)
                    .contentTransition(.numericText())
                Text("words learned · \(periodText)").font(.system(size: 14)).foregroundStyle(AppColor.ash)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.accuracyPercent.map { "\($0)%" } ?? "—")
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColor.accent)
                Text("accuracy").font(.system(size: 12)).foregroundStyle(AppColor.smoke)
            }
        }
        .padding(.top, 8)
        .animation(.snappy, value: viewModel.learned)
    }

    private var periodText: String {
        switch viewModel.period {
        case .week: String(localized: "last 7 days")
        case .month: String(localized: "last 30 days")
        case .all: String(localized: "all time")
        }
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("[ activity · 12 weeks ]").bracketLabel()
                Spacer()
                HStack(spacing: 4) {
                    Text("less").font(.system(size: 10, design: .monospaced)).foregroundStyle(AppColor.smoke)
                    ForEach([0, 2, 4], id: \.self) { HeatDot(level: $0).frame(width: 8, height: 8) }
                    Text("more").font(.system(size: 10, design: .monospaced)).foregroundStyle(AppColor.smoke)
                }
            }
            HeatGrid(cells: viewModel.heat)
                .aspectRatio(12.0 / 7.0, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Daily activity over the last 12 weeks"))
        }
        .padding(16)
        .glassCard(cornerRadius: 26)
    }

    private var distribution: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("[ vocabulary ]").bracketLabel()
            ForEach(viewModel.distribution, id: \.status) { item in
                HStack(spacing: 10) {
                    Text(item.status.rawValue)
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.ash)
                        .frame(width: 92, alignment: .leading)
                    Text(String(repeating: "▮", count: bars(item.count)))
                        .font(.system(size: 12, design: .monospaced)).tracking(1.2)
                        .foregroundStyle(color(item.status))
                    Spacer()
                    Text("\(item.count)").font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 4).padding(.top, 4)
    }

    private func bars(_ count: Int) -> Int {
        count == 0 ? 0 : max(1, Int((Double(count) / Double(viewModel.maxDistribution) * 12).rounded()))
    }

    private func color(_ status: LearningStatus) -> Color {
        switch status {
        case .remembered: AppColor.statusRemembered
        case .reviewing: AppColor.statusReviewing
        case .learning: AppColor.statusLearning
        case .known: AppColor.accent
        default: AppColor.faint
        }
    }
}

/// Тепловая карта 12 недель × 7 дней. Рисуется в `Canvas`: размеры считаются без вложенных aspectRatio.
private struct HeatGrid: View {
    let cells: [HeatCell]
    private let opacities: [Double] = [0, 0.3, 0.55, 0.8, 1]

    var body: some View {
        Canvas { context, size in
            let gap: CGFloat = 5
            let cell = (size.width - gap * 11) / 12
            for item in cells {
                let week = item.id / 7, day = item.id % 7
                let rect = CGRect(x: CGFloat(week) * (cell + gap), y: CGFloat(day) * (cell + gap), width: cell, height: cell)
                let level = min(item.level, 4)
                if level == 0 {
                    context.fill(Path(ellipseIn: rect), with: .color(AppColor.hairline))
                } else {
                    if level == 4 {
                        context.fill(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(AppColor.glow.opacity(0.25)))
                    }
                    context.fill(Path(ellipseIn: rect), with: .color(AppColor.fill.opacity(opacities[level])))
                }
            }
        }
    }
}

private struct HeatDot: View {
    let level: Int

    var body: some View {
        Circle()
            .fill(level == 0 ? AppColor.hairline : AppColor.fill.opacity([0, 0.3, 0.55, 0.8, 1][min(level, 4)]))
            .shadow(color: level == 4 ? AppColor.glow.opacity(0.8) : .clear, radius: 3)
    }
}
