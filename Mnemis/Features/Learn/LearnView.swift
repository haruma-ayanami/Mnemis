import SwiftUI

/// Экран обучения (ABOUT.md, раздел 29): карточка, ответ с оценкой, итоги или «всё сделано».
struct LearnView: View {
    @State private var viewModel: LearnViewModel
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: LearnViewModel(container: container))
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            switch viewModel.state {
            case .loading:
                LoadingView()
            case .failed(let message):
                ErrorStateView(message: message)
            case .loaded:
                if let word = viewModel.current {
                    FlashcardView(viewModel: viewModel, word: word, onClose: close)
                        .id(word.id)
                } else if viewModel.isSessionFinished {
                    SessionSummaryView(viewModel: viewModel, onDone: close)
                } else {
                    LearnEmptyView(viewModel: viewModel)
                }
            }
        }
        .mnemisTabBarHidden(viewModel.current != nil)
        .onAppear { viewModel.startIfNeeded() }
    }

    private func close() {
        container.router.selectedTab = .today
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
