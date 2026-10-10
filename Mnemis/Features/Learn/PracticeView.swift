import SwiftUI

/// Вкладка «Practice» на экране Learn: сколько вопросов можно собрать и старт сессии.
struct PracticeDeckView: View {
    let plan: PracticePlan?
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let plan, !plan.isEmpty {
                deck(plan)
                    .screenEntrance(delay: 0.04)
                composition(plan)
                    .padding(.top, 18)
                    .screenEntrance(delay: 0.1)
                Spacer(minLength: 16)
                Button(action: onStart) {
                    HStack(spacing: 8) {
                        Text("Start practice")
                        Text("· \(questionsLabel(min(PracticeUseCase.sessionSize, plan.active + plan.remembered)))")
                            .font(.system(size: 14, design: .monospaced)).opacity(0.6)
                        Text("→").font(.system(size: 15, design: .monospaced))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 12)
                .screenEntrance(delay: 0.16)
            } else {
                emptyState
                    .screenEntrance()
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func questionsLabel(_ count: Int) -> String {
        count == 1 ? String(localized: "1 question") : String(localized: "\(count) questions")
    }

    /// Карточка упражнения: вопросы из слов, которые учит пользователь.
    private func deck(_ plan: PracticePlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("[ practice ]").bracketLabel(AppColor.accent)
                Spacer()
                Text("4 options").font(.system(size: 13, design: .monospaced)).foregroundStyle(AppColor.smoke)
            }
            Text("Pick the right answer")
                .padding(.top, 22)
                .font(.system(size: 30, weight: .semibold)).tracking(-0.8)
                .foregroundStyle(AppColor.ink)
            Text("Words you are learning come back as meanings, gaps in sentences and reverse questions.")
                .font(.system(size: 15)).foregroundStyle(AppColor.ash)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24).padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 34)
        .cornerMarks(inset: 14)
    }

    private func composition(_ plan: PracticePlan) -> some View {
        VStack(spacing: 0) {
            row("Learning", plan.learning)
            Divider().overlay(AppColor.hairline)
            row("Reviewing", plan.reviewing)
            Divider().overlay(AppColor.hairline)
            row("Remembered · sometimes", plan.remembered)
            Divider().overlay(AppColor.hairline)
            row("Known · at most one a session", min(plan.known, 1))
        }
        .padding(.horizontal, 18).padding(.vertical, 6)
        .glassCard(cornerRadius: 24)
    }

    private func row(_ title: LocalizedStringKey, _ value: Int) -> some View {
        HStack {
            Text(title).font(.system(size: 15)).foregroundStyle(AppColor.ink)
            Spacer()
            Text(String(format: "%02d", value))
                .font(.system(size: 15, weight: .medium, design: .monospaced)).foregroundStyle(AppColor.ink)
        }
        .frame(minHeight: 46)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("[ practice ]").bracketLabel()
            Text("Nothing to practice yet")
                .font(.system(size: 24, weight: .semibold)).foregroundStyle(AppColor.ink)
            Text("Start learning a few words in Cards. Practice uses the words you are learning.")
                .font(.system(size: 15)).foregroundStyle(AppColor.ash)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .padding(.top, 40)
    }
}

/// Сессия упражнений на весь экран: вопрос, четыре варианта, подсказка-результат.
struct PracticeSessionView: View {
    let viewModel: PracticeViewModel
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            DecorLayer {
                DotRings().frame(width: 610, height: 610).opacity(0.4)
            }
            if viewModel.isFinished {
                PracticeSummaryView(viewModel: viewModel, onDone: onClose)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let question = viewModel.current {
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 24)
                    questionCard(question)
                    Spacer(minLength: 24)
                    options(question)
                    feedback
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .id(question.id)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 44)),
                    removal: .opacity.combined(with: .offset(x: -44))
                ))
            }
        }
        .animation(reduceMotion ? Motion.reduced : Motion.swap, value: viewModel.index)
        .animation(reduceMotion ? Motion.reduced : Motion.swap, value: viewModel.isFinished)
        .mnemisHaptic(.light, trigger: viewModel.results.count)
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundGlassButton(systemImage: "xmark", label: "End practice", action: onClose)
            VStack(alignment: .leading, spacing: 5) {
                Text("\(String(format: "%02d", viewModel.index + 1)) / \(String(format: "%02d", viewModel.questions.count)) · \(viewModel.correctCount) right")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
                    .contentTransition(.numericText())
            }
            Spacer()
        }
    }

    private func questionCard(_ question: PracticeQuestion) -> some View {
        VStack(spacing: 16) {
            Text(label(question.kind)).bracketLabel(AppColor.accent)
            Text(question.prompt)
                .font(question.kind == .context ? .system(size: 22, weight: .medium) : .mnemisWordLarge)
                .tracking(question.kind == .context ? -0.2 : -2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24).padding(.vertical, 40)
        .glassCard(cornerRadius: 36)
        .cornerMarks(inset: 14)
    }

    private func options(_ question: PracticeQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(question.options, id: \.wordID) { option in
                OptionButton(
                    text: option.text,
                    state: optionState(option, in: question),
                    action: { viewModel.choose(option) }
                )
            }
        }
    }

    private func optionState(_ option: PracticeOption, in question: PracticeQuestion) -> OptionButton.State {
        guard let selected = viewModel.selected else { return .idle }
        if question.isCorrect(option) { return .correct }
        if option == selected { return .wrong }
        return .dimmed
    }

    @ViewBuilder
    private var feedback: some View {
        if viewModel.selected != nil {
            Button { viewModel.next() } label: {
                HStack(spacing: 10) {
                    Text(viewModel.index + 1 < viewModel.questions.count ? "Next" : "See result")
                    Text("→").font(.system(size: 15, design: .monospaced))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 16)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            Text(hint)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColor.smoke)
                .padding(.top, 16)
                .frame(height: 56)
        }
    }

    private var hint: String {
        switch viewModel.current?.kind {
        case .meaning: "pick the meaning"
        case .reverse: "pick the word"
        case .context: "pick the word that fits"
        case nil: ""
        }
    }

    private func label(_ kind: PracticeKind) -> LocalizedStringKey {
        switch kind {
        case .meaning: "[ what does it mean? ]"
        case .reverse: "[ which word? ]"
        case .context: "[ fill the gap ]"
        }
    }
}

/// Вариант ответа: после выбора правильный подсвечивается, неправильно выбранный — красным.
private struct OptionButton: View {
    enum State { case idle, correct, wrong, dimmed }

    let text: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 16)
                .background(background, in: .rect(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(stroke, lineWidth: state == .idle ? 1 : 1.5))
                .opacity(state == .dimmed ? 0.4 : 1)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(state != .idle)
        .animation(Motion.swap, value: state)
    }

    private var foreground: Color {
        switch state {
        case .correct: AppColor.onFill
        case .wrong: .red
        default: AppColor.ink
        }
    }

    private var background: AnyShapeStyle {
        switch state {
        case .correct: AnyShapeStyle(AppColor.fill)
        default: AnyShapeStyle(AppColor.surface)
        }
    }

    private var stroke: Color {
        switch state {
        case .correct: AppColor.fill
        case .wrong: .red.opacity(0.7)
        default: AppColor.hairline
        }
    }
}

/// Итог сессии: сколько верных и последовательность точек, как в итогах Learn.
struct PracticeSummaryView: View {
    let viewModel: PracticeViewModel
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 80)
            Text("[ practice done ]").bracketLabel(AppColor.accent)
            Text("\(viewModel.correctCount) of \(viewModel.questions.count) right")
                .font(.mnemisTitle).tracking(-0.8)
                .foregroundStyle(AppColor.ink)
            HStack(spacing: 8) {
                ForEach(Array(viewModel.results.enumerated()), id: \.offset) { _, right in
                    Circle()
                        .fill(right ? AppColor.fill : .clear)
                        .overlay(Circle().stroke(right ? .clear : .red.opacity(0.7), lineWidth: 1.2))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.top, 6)
            Text("Practice doesn't change your schedule. Cards in Learn do.")
                .font(.system(size: 14)).foregroundStyle(AppColor.ash)
            Spacer()
            Button(action: onDone) {
                HStack(spacing: 10) { Text("Done"); Text("→").font(.system(size: 15, design: .monospaced)) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}
