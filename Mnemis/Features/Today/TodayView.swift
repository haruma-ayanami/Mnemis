import SwiftUI

/// Главный экран: слово дня, повторения, серия и неделя (ABOUT.md, раздел 15).
struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @State private var cardTab: DailyCardTab = .word

    init(container: AppContainer) {
        _viewModel = State(initialValue: TodayViewModel(container: container))
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppColor.background.ignoresSafeArea()
            backdrop
            content
        }
        .onAppear { viewModel.load() }
    }

    private var backdrop: some View {
        DecorLayer(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                GlowHalo().frame(width: 420, height: 420).offset(x: 140, y: -60)
                DotSphere().frame(width: 300, height: 300).offset(x: 80, y: 10)
            }
        }
        .overlay(alignment: .bottom) {
            DecorLayer { MeshFloor().frame(height: 300).opacity(0.8) }
                .frame(height: 300)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LoadingView()
        case .failed(let message):
            ErrorStateView(message: message)
        case .loaded:
            ScrollView {
                // Блоки появляются по очереди сверху вниз: взгляд идёт от слова дня к кнопке сессии.
                VStack(alignment: .leading, spacing: 12) {
                    header.screenEntrance()
                    Spacer().frame(height: 70)
                    wordCard.screenEntrance(delay: 0.05)
                    tiles.screenEntrance(delay: 0.1)
                    WeekStrip(days: viewModel.week).screenEntrance(delay: 0.14)
                    startButton.screenEntrance(delay: 0.18)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day(.twoDigits).month(.abbreviated)))
                    .bracketLabel()
                Text("Today")
                    .font(.mnemisTitle)
                    .tracking(-0.8)
                    .foregroundStyle(AppColor.ink)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(AppColor.fill).frame(width: 8, height: 8)
                    .shadow(color: AppColor.glow.opacity(0.9), radius: 5)
                Text("^[\(viewModel.streak) day](inflect: true)")
                    .font(.system(size: 13, design: .monospaced))
            }
            .foregroundStyle(AppColor.ink)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .glassCapsule()
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var wordCard: some View {
        if let phrase = viewModel.phrase {
            VStack(alignment: .leading, spacing: 12) {
                DailyCardTabs(selection: $cardTab)
                if cardTab == .phrase {
                    PhraseCard(phrase: phrase)
                        .transition(.asymmetric(insertion: .offset(x: 32).combined(with: .opacity), removal: .opacity))
                } else {
                    dailyWordCard
                        .transition(.asymmetric(insertion: .offset(x: -32).combined(with: .opacity), removal: .opacity))
                }
            }
            .animation(Motion.swap, value: cardTab)
        } else {
            dailyWordCard
        }
    }

    @ViewBuilder
    private var dailyWordCard: some View {
        if let word = viewModel.dailyWord {
            WordCard(word: word, example: viewModel.dailyExample)
        } else {
            EmptyStateView(
                title: "No word for today",
                systemImage: "book.closed",
                message: "Add a word in Words, or there are no unlearned words left for your level."
            )
            .glassCard()
        }
    }

    private var tiles: some View {
        HStack(spacing: 10) {
            StatTile(title: "to review", text: String(format: "%03d", viewModel.dueCount))
            StatTile(title: "new today", text: "\(viewModel.newStarted)", secondary: "/\(viewModel.newLimit)")
            StatTile(title: "session", text: "~\(viewModel.estimatedMinutes)", secondary: "m")
        }
    }

    private var startButton: some View {
        Button { viewModel.openLearn() } label: {
            HStack(spacing: 8) {
                Text("Start session")
                if viewModel.cardCount > 0 {
                    Text("· \(viewModel.cardCount) cards").font(.system(size: 14, design: .monospaced)).opacity(0.6)
                }
                Text("→").font(.system(size: 15, design: .monospaced))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 4)
    }
}

/// Неделя по дням: сделано (зелёная точка), сегодня (кольцо), пропущено, впереди.
struct WeekStrip: View {
    let days: [WeekDay]

    var body: some View {
        HStack {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.letter)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(day.state == .today ? AppColor.ink : AppColor.smoke)
                    marker(day.state)
                        .frame(height: 10)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .glassCard(cornerRadius: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("This week"))
        .accessibilityValue(Text("\(days.filter { $0.state == .done }.count) days done"))
    }

    @ViewBuilder
    private func marker(_ state: WeekDayState) -> some View {
        switch state {
        case .done:
            Circle().fill(AppColor.fill).frame(width: 8, height: 8).shadow(color: AppColor.glow.opacity(0.8), radius: 4)
        case .today:
            Circle().stroke(AppColor.accent, lineWidth: 1.5).frame(width: 8, height: 8)
        case .missed:
            Circle().stroke(AppColor.faint, lineWidth: 1.5).frame(width: 8, height: 8)
        case .upcoming:
            Circle().fill(AppColor.faint).frame(width: 4, height: 4)
        }
    }
}
