import SwiftUI

/// Вкладка Learn (ABOUT.md, раздел 29): колода на сегодня и кнопка старта.
/// Сама сессия открывается на весь экран «зумом» из кнопки, поэтому панель вкладок не исчезает рывком, а уходит под сессию.
struct LearnView: View {
    @State private var viewModel: LearnViewModel
    @State private var isInSession = false
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: LearnViewModel(container: container))
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            DecorLayer {
                DotRings().frame(width: 610, height: 610).opacity(0.45)
            }
            content
        }
        .animation(reduceMotion ? Motion.reduced : Motion.enter, value: viewModel.current == nil)
        .onAppear { viewModel.startIfNeeded() }
        .task(id: container.router.sessionRequest) { await openRequestedSession() }
        .fullScreenCover(isPresented: $isInSession) {
            LearnSessionView(viewModel: viewModel, onClose: { isInSession = false })
                .navigationTransition(.zoom(sourceID: Self.startSource, in: zoom))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LoadingView()
        case .failed(let message):
            ErrorStateView(message: message)
        case .loaded:
            if viewModel.current != nil {
                LearnDeckView(viewModel: viewModel, zoom: zoom, sourceID: Self.startSource) {
                    viewModel.refreshQueuedWords()
                    isInSession = true
                }
                .transition(.opacity)
            } else {
                LearnEmptyView(viewModel: viewModel)
                    .screenEntrance()
                    .transition(.opacity)
            }
        }
    }

    /// Запрос с Today или из уведомления: даём вкладке появиться, затем разворачиваем сессию.
    private func openRequestedSession() async {
        guard container.router.sessionRequest > 0, !isInSession else { return }
        viewModel.startIfNeeded()
        try? await Task.sleep(for: .milliseconds(160))
        guard !Task.isCancelled, viewModel.current != nil else { return }
        isInSession = true
    }

    private static let startSource = "learn-session"
}

/// Сессия во весь экран: карточки, затем итоги. Следующая карточка въезжает справа, прошлая уходит влево.
private struct LearnSessionView: View {
    let viewModel: LearnViewModel
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            DecorLayer {
                DotRings().frame(width: 610, height: 610).opacity(0.45)
            }
            if let word = viewModel.current {
                FlashcardView(viewModel: viewModel, word: word, onClose: onClose)
                    .id(word.id)
                    .transition(cardTransition)
            } else if viewModel.isSessionFinished {
                SessionSummaryView(viewModel: viewModel, onDone: onClose)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(reduceMotion ? Motion.reduced : Motion.swap, value: viewModel.current?.id)
        .animation(reduceMotion ? Motion.reduced : Motion.enter, value: viewModel.isSessionFinished)
        .mnemisHaptic(.light, trigger: viewModel.reviewedCount)
        .onChange(of: viewModel.current == nil && !viewModel.isSessionFinished) { _, isEmpty in
            // «Я уже знаю» на последней карточке без оценок: показывать нечего, закрываем.
            if isEmpty { onClose() }
        }
    }

    private var cardTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 44)),
            removal: .opacity.combined(with: .offset(x: -44))
        )
    }
}

/// Колода на сегодня: сколько карточек, из них новых и повторений, примерное время.
/// Передняя карточка — источник «зума» для сессии; две задние выглядывают снизу, как стопка.
private struct LearnDeckView: View {
    let viewModel: LearnViewModel
    let zoom: Namespace.ID
    let sourceID: String
    let onStart: () -> Void

    private static let cardHeight: CGFloat = 270

    private var remaining: Int { viewModel.queue.count }
    private var minutes: Int { max(1, Int((Double(remaining) * 20 / 60).rounded())) }
    private var remainingNew: Int { viewModel.remainingNewCount }
    private var remainingReviews: Int { viewModel.remainingReviewCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Learn")
                .font(.mnemisTitle).tracking(-0.8)
                .foregroundStyle(AppColor.ink)
                .screenEntrance()

            Button(action: onStart) { deck }
                .buttonStyle(PressScaleStyle())
                .padding(.top, 28)
                .screenEntrance(delay: 0.06, distance: 30)
                .accessibilityLabel(Text("Start session, \(remaining) cards"))

            plan
                .padding(.top, 4)
                .screenEntrance(delay: 0.12)

            Spacer(minLength: 16)

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Text(viewModel.reviewedCount > 0 ? "Continue session" : "Start session")
                    Text("· \(remaining) cards").font(.system(size: 14, design: .monospaced)).opacity(0.6)
                    Text("→").font(.system(size: 15, design: .monospaced))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.bottom, 12)
            .screenEntrance(delay: 0.16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// Задние карточки той же высоты, сжаты по ширине и сдвинуты вниз: видны только их нижние края.
    private var deck: some View {
        ZStack(alignment: .top) {
            ForEach([2, 1], id: \.self) { depth in
                RoundedRectangle(cornerRadius: 34)
                    .fill(AppColor.surface.opacity(depth == 1 ? 0.8 : 0.55))
                    .overlay(RoundedRectangle(cornerRadius: 34).stroke(AppColor.hairline))
                    .frame(height: Self.cardHeight)
                    .padding(.horizontal, CGFloat(depth) * 14)
                    .offset(y: CGFloat(depth) * 13)
                    .opacity(remaining > depth ? 1 : 0)
            }
            front
                .frame(height: Self.cardHeight)
                .matchedTransitionSource(id: sourceID, in: zoom) { source in
                    source.clipShape(.rect(cornerRadius: 34))
                }
        }
        .padding(.bottom, 26)
    }

    private var front: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(viewModel.reviewedCount > 0 ? "[ in progress ]" : "[ today's deck ]")
                    .bracketLabel(AppColor.accent)
                Spacer()
                Text("~\(minutes) min")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
            }
            Spacer(minLength: 8)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(String(format: "%02d", remaining))
                    .font(.system(size: 92, weight: .medium, design: .monospaced))
                    .tracking(-4)
                    .foregroundStyle(AppColor.ink)
                    .contentTransition(.numericText())
                Text(remaining == 1 ? "card" : "cards")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppColor.ash)
            }
            Spacer(minLength: 8)
            HStack(alignment: .center) {
                DeckComposition(new: remainingNew, reviews: remainingReviews)
                Spacer()
                Text("tap to start →")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 34)
        .cornerMarks(inset: 14)
    }

    /// План сессии: из чего состоит колода и когда следующее повторение после неё.
    private var plan: some View {
        VStack(spacing: 0) {
            planRow(marker: AnyView(dot(filled: true)), "New words", String(format: "%02d", remainingNew))
            Divider().overlay(AppColor.hairline)
            planRow(marker: AnyView(dot(filled: false)), "Reviews", String(format: "%02d", remainingReviews))
            Divider().overlay(AppColor.hairline)
            planRow(marker: AnyView(Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(AppColor.smoke)),
                    "Next review after this", viewModel.nextReviewDate.map { $0.formatted(.dateTime.hour().minute()) } ?? "—")
        }
        .padding(.horizontal, 18).padding(.vertical, 6)
        .glassCard(cornerRadius: 24)
    }

    private func planRow(marker: AnyView, _ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 12) {
            marker.frame(width: 14)
            Text(title).font(.system(size: 15)).foregroundStyle(AppColor.ink)
            Spacer()
            Text(value).font(.system(size: 15, weight: .medium, design: .monospaced)).foregroundStyle(AppColor.ink)
                .contentTransition(.numericText())
        }
        .frame(minHeight: 46)
        .accessibilityElement(children: .combine)
    }

    private func dot(filled: Bool) -> some View {
        Circle()
            .fill(filled ? AppColor.fill : .clear)
            .overlay(Circle().stroke(filled ? .clear : AppColor.smoke, lineWidth: 1.2))
            .frame(width: 8, height: 8)
    }
}

/// Состав колоды точками: зелёные — новые слова, кольца — повторения. Больше 24 карточек сжимается в «+N».
private struct DeckComposition: View {
    let new: Int
    let reviews: Int

    private static let limit = 24

    var body: some View {
        let total = new + reviews
        let shown = min(total, Self.limit)
        let shownNew = total == 0 ? 0 : Int((Double(new) / Double(total) * Double(shown)).rounded())
        HStack(spacing: 6) {
            ForEach(0..<shown, id: \.self) { index in
                Circle()
                    .fill(index < shownNew ? AppColor.fill : .clear)
                    .overlay(Circle().stroke(index < shownNew ? .clear : AppColor.smoke, lineWidth: 1.2))
                    .frame(width: 9, height: 9)
                    .shadow(color: index < shownNew ? AppColor.glow.opacity(0.6) : .clear, radius: 3)
            }
            if total > shown {
                Text("+\(total - shown)").font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColor.smoke)
            }
        }
        .accessibilityHidden(true)
    }
}

/// «Всё сделано»: время следующего повторения и спокойное сообщение.
struct LearnEmptyView: View {
    let viewModel: LearnViewModel

    var body: some View {
        ZStack {
            DecorLayer {
                DotRings().frame(width: 640, height: 640).opacity(0.55)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Learn")
                    .font(.mnemisTitle).tracking(-0.8)
                    .foregroundStyle(AppColor.ink)

                VStack(spacing: 14) {
                    Text("[ next review ]").bracketLabel(AppColor.accent)
                    if let next = viewModel.nextReviewDate {
                        Text(next, format: .dateTime.hour().minute())
                            .font(.system(size: 76, weight: .medium, design: .monospaced))
                            .tracking(-3.4)
                            .foregroundStyle(AppColor.ink)
                        Text("in \(next, style: .relative) · \(viewModel.dueSoonCount) words")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(AppColor.smoke)
                    } else {
                        Text("—")
                            .font(.system(size: 76, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppColor.faint)
                        Text("nothing scheduled yet")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(AppColor.smoke)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 110)

                VStack(alignment: .leading, spacing: 8) {
                    Text("All caught up.")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Today's new words are done and nothing is due. Rest helps memory too.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColor.ash)
                }
                .foregroundStyle(AppColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .glassCard()
                .padding(.top, 56)

                Button { viewModel.restart() } label: { Text("Learn 3 extra words") }
                    .buttonStyle(GlassButtonStyle())
                    .padding(.top, 12)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}
