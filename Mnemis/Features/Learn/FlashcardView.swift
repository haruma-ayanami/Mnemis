import SwiftUI

/// Поворот карточки вокруг вертикальной оси: вопрос уходит на 90°, ответ приходит с другой стороны (спецификация «Motion»).
private struct FlipEffect: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

private extension AnyTransition {
    static func flip(from angle: Double) -> AnyTransition {
        .modifier(active: FlipEffect(angle: angle), identity: FlipEffect(angle: 0)).combined(with: .opacity)
    }
}

/// Флэшкарта (ABOUT.md, раздел 7): сначала слово, затем ответ и оценка Again/Hard/Good/Easy.
struct FlashcardView: View {
    let viewModel: LearnViewModel
    let word: Word
    let onClose: () -> Void

    @State private var isRevealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                if isRevealed {
                    answerCard
                        .padding(.top, 30)
                        .transition(cardTransition(angle: 90))
                    Spacer(minLength: 12)
                    ratingRow
                } else {
                    Spacer()
                    questionCard
                        .transition(cardTransition(angle: -90))
                    Spacer()
                    questionActions
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86), value: isRevealed)
    }

    /// С Reduce Motion карточка просто плавно появляется, без поворота.
    private func cardTransition(angle: Double) -> AnyTransition {
        reduceMotion ? .opacity : .flip(from: angle)
    }

    // MARK: - Части

    private var header: some View {
        HStack(spacing: 14) {
            RoundGlassButton(systemImage: "xmark", label: "End session", action: onClose)
            VStack(alignment: .leading, spacing: 5) {
                DotProgress(done: viewModel.reviewedCount, total: viewModel.totalCount)
                Text("\(String(format: "%02d", viewModel.reviewedCount + 1)) / \(String(format: "%02d", viewModel.totalCount)) · \(viewModel.newCount) new · \(viewModel.reviewCount) reviews")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
            }
            Spacer()
        }
    }

    private var questionCard: some View {
        Button {
            isRevealed = true
        } label: {
            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    Text(viewModel.currentStatus == .new ? "[ new word ]" : "[ review ]")
                        .bracketLabel()
                    if viewModel.currentStatus != .new {
                        MemoryBar(level: viewModel.currentStatus.strength)
                    }
                }
                Text(word.lemma)
                    .font(.mnemisWordLarge)
                    .tracking(-2.1)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(AppColor.ink)
                if let ipa = word.ipa {
                    Text(ipa).font(.system(size: 17, design: .monospaced)).foregroundStyle(AppColor.ash)
                }
                SpeakButton(text: word.lemma)
                    .padding(.top, 6)
                Text("recall the meaning · tap to reveal")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 60).padding(.bottom, 44)
            .glassCard(cornerRadius: 36)
            .cornerMarks(inset: 14)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text("Show answer for \(word.lemma)"))
    }

    private var questionActions: some View {
        VStack(spacing: 10) {
            Button { isRevealed = true } label: { Text("Show answer") }
                .buttonStyle(GlassButtonStyle())
            Button { viewModel.markCurrentKnown() } label: { Text("I already know this word") }
                .buttonStyle(QuietButtonStyle())
        }
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.lemma)
                        .font(.system(size: 42, weight: .semibold)).tracking(-1.5)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text([word.ipa, word.meanings.count > 1 ? nil : word.partOfSpeech.map(Self.abbreviation), word.level].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(AppColor.ash)
                }
                Spacer()
                SpeakButton(text: word.lemma)
            }
            AsciiDivider()
            MeaningsList(meanings: word.allMeanings, primarySize: 25)
            if let definition = word.definition {
                Text(definition).font(.system(size: 16)).foregroundStyle(AppColor.ash)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.currentExamples.prefix(2)) { example in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(example.isUserCreated ? "you" : "ex.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppColor.smoke)
                            .frame(width: 34, alignment: .leading)
                        Text(highlight(example.sentence)).font(.system(size: 15))
                    }
                }
            }
            .padding(.top, 4)
        }
        .foregroundStyle(AppColor.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24).padding(.vertical, 28)
        .glassCard(cornerRadius: 36)
        .cornerMarks(inset: 14)
    }

    private var ratingRow: some View {
        VStack(spacing: 12) {
            Text("── how well did you remember? ──")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColor.smoke)
            HStack(spacing: 8) {
                ForEach(ReviewRating.allCases, id: \.self) { rating in
                    RatingButton(rating: rating, interval: viewModel.intervalLabel(for: rating)) {
                        viewModel.rate(rating)
                    }
                }
            }
        }
    }

    private static func abbreviation(_ partOfSpeech: String) -> String {
        switch partOfSpeech {
        case "noun": "n"
        case "verb": "v"
        case "adjective": "adj"
        case "adverb": "adv"
        case "preposition": "prep"
        default: partOfSpeech
        }
    }

    private func highlight(_ sentence: String) -> AttributedString {
        var text = AttributedString(sentence)
        text.foregroundColor = AppColor.ink
        if let range = text.range(of: word.lemma, options: .caseInsensitive) {
            text[range].foregroundColor = AppColor.accent
        }
        return text
    }
}

private struct RatingButton: View {
    let rating: ReviewRating
    let interval: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title).font(.system(size: 16, weight: .medium))
                Text(interval).font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(rating == .easy ? AppColor.onFill.opacity(0.7) : AppColor.smoke)
            }
            .foregroundStyle(rating == .easy ? AppColor.onFill : AppColor.ink)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background {
                if rating == .easy {
                    RoundedRectangle(cornerRadius: 24).fill(AppColor.fill)
                        .shadow(color: AppColor.glow.opacity(0.4), radius: 14)
                }
            }
            .modifier(RatingGlass(isEasy: rating == .easy))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(interval))
    }

    private var title: LocalizedStringKey {
        switch rating {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }
}

private struct RatingGlass: ViewModifier {
    let isEasy: Bool

    func body(content: Content) -> some View {
        if isEasy { content } else { content.glassCard(cornerRadius: 24) }
    }
}

/// Кнопка озвучивания слова.
struct SpeakButton: View {
    let text: String

    var body: some View {
        Button { SpeechPlayer.shared.speak(text) } label: {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppColor.ink)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(AppColor.hairline))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text("Play pronunciation"))
    }
}
