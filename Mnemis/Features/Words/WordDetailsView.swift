import SwiftUI

/// Детали слова: память, значение, примеры, действия со статусом (ARCHITECTURE.md, этап 3).
struct WordDetailsView: View {
    @State private var viewModel: WordDetailsViewModel
    @State private var newExample = ""
    @State private var note: String
    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss

    init(word: Word, container: AppContainer, onChange: @escaping () -> Void) {
        _viewModel = State(initialValue: WordDetailsViewModel(word: word, container: container, onChange: onChange))
        _note = State(initialValue: word.userNote ?? "")
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            DotGridBackdrop().frame(height: 300).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    wordHeader
                    memoryCard
                    meaning
                    examples
                    noteSection
                    sources
                    actions
                    if viewModel.word.origin == .user {
                        Button(role: .destructive) {
                            if viewModel.delete() { dismiss() }
                        } label: {
                            Text("Delete").font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .mnemisNavigationBarHidden()
        .sheet(isPresented: $isEditing) { EditWordView(viewModel: viewModel) }
    }

    private var topBar: some View {
        HStack {
            RoundGlassButton(systemImage: "chevron.left", label: "Back to Words") { dismiss() }
            Spacer()
            Button { isEditing = true } label: { Text("Edit").font(.system(size: 15, weight: .medium)).foregroundStyle(AppColor.ink).padding(.horizontal, 18).frame(minHeight: 44) }
                .buttonStyle(PressScaleStyle())
                .glassCapsule()
        }
        .padding(.top, 8)
    }

    private var wordHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.word.lemma)
                        .font(.system(size: 46, weight: .semibold)).tracking(-1.6)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    if let ipa = viewModel.word.ipa {
                        Text(ipa).font(.system(size: 15, design: .monospaced)).foregroundStyle(AppColor.ash)
                    }
                }
                Spacer()
                SpeakButton(text: viewModel.word.lemma)
            }
            FlowPills(items: pills)
        }
        .foregroundStyle(AppColor.ink)
        .padding(.top, 6)
    }

    private var pills: [String] {
        var result: [String] = []
        if viewModel.word.meanings.count > 1 {
            result += viewModel.word.meanings.map(\.partOfSpeech)
        } else if let pos = viewModel.word.partOfSpeech {
            result.append(pos)
        }
        if let level = viewModel.word.level { result.append(level) }
        if let rank = viewModel.word.frequencyRank { result.append("freq #\(rank)") }
        result.append(viewModel.word.origin == .user ? "yours" : "built-in")
        return result
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    StatusDot(status: viewModel.status)
                    Text(statusTitle).font(.system(size: 16, weight: .medium))
                }
                Spacer()
                MemoryBar(level: viewModel.status.strength)
            }
            HStack {
                metric(nextText, "next review")
                metric(intervalText, "interval")
                metric("\(viewModel.progress?.correctCount ?? 0) / \(viewModel.progress?.incorrectCount ?? 0)", "right / wrong")
            }
        }
        .foregroundStyle(AppColor.ink)
        .padding(.horizontal, 22).padding(.vertical, 20)
        .glassCard()
        .cornerMarks()
    }

    private func metric(_ value: String, _ title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 19, weight: .medium, design: .monospaced))
            Text(title).font(.system(size: 12)).foregroundStyle(AppColor.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusTitle: String {
        switch viewModel.status {
        case .new: "Not started"
        case .learning: "Learning"
        case .reviewing: "Reviewing"
        case .remembered: "Remembered"
        case .known: "Known"
        case .suspended: "Suspended"
        }
    }

    private var nextText: String {
        guard let next = viewModel.progress?.nextReviewAt else { return "—" }
        return next.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
    }

    private var intervalText: String {
        guard let days = viewModel.progress?.intervalDays, days > 0 else { return "—" }
        return LearnViewModel.format(days: days).replacingOccurrences(of: "<", with: "")
    }

    private var meaning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("[ meaning ]").bracketLabel()
            MeaningsList(meanings: viewModel.word.allMeanings, primarySize: 20)
            if let definition = viewModel.word.definition, !definition.isEmpty {
                Text(definition).font(.system(size: 15)).foregroundStyle(AppColor.ash)
            }
        }
        .foregroundStyle(AppColor.ink)
        .padding(.horizontal, 4)
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("[ examples ]").bracketLabel()
            ForEach(viewModel.examples) { example in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(example.isUserCreated ? "you" : "src")
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
                        .frame(width: 34, alignment: .leading)
                    Text(example.sentence).font(.system(size: 15)).foregroundStyle(AppColor.ink)
                }
            }
            HStack {
                TextField("Add your example", text: $newExample)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.ink)
                    .onSubmit(addExample)
                Button("Add", action: addExample)
                    .buttonStyle(PressScaleStyle())
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(newExample.trimmingCharacters(in: .whitespaces).isEmpty ? AppColor.faint : AppColor.accent)
                    .disabled(newExample.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14).frame(minHeight: 44)
            .overlay(Capsule().stroke(AppColor.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .padding(.horizontal, 4)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("[ note ]").bracketLabel()
            TextField("Your note", text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(AppColor.ink)
                .padding(14)
                .glassCard(cornerRadius: 20)
                .onSubmit { viewModel.saveNote(note) }
            if note != (viewModel.word.userNote ?? "") {
                Button("Save note") { viewModel.saveNote(note) }
                    .buttonStyle(PressScaleStyle()).font(.system(size: 14, weight: .medium)).foregroundStyle(AppColor.accent)
            }
        }
        .padding(.horizontal, 4)
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { Task { await viewModel.enrich() } } label: {
                HStack(spacing: 8) {
                    if viewModel.isEnriching { ProgressView() } else { Image(systemName: "arrow.triangle.2.circlepath") }
                    Text("Fetch details from sources")
                }
                .font(.system(size: 14, weight: .medium)).foregroundStyle(AppColor.ash)
            }
            .buttonStyle(PressScaleStyle()).disabled(viewModel.isEnriching)
            if let message = viewModel.message {
                Text(message).font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 8) {
            switch viewModel.status {
            case .known:
                Button { viewModel.restoreToLearning() } label: { Text("Back to learning") }.buttonStyle(GlassButtonStyle(height: 48))
            case .suspended:
                Button { viewModel.resume() } label: { Text("Resume") }.buttonStyle(GlassButtonStyle(height: 48))
            default:
                Button { viewModel.markKnown() } label: { Text("I know this") }.buttonStyle(GlassButtonStyle(height: 48))
                Button { viewModel.suspend() } label: { Text("Suspend") }
                    .buttonStyle(QuietButtonStyle())
                    .overlay(Capsule().stroke(AppColor.hairline))
            }
        }
    }

    private func addExample() {
        viewModel.addExample(newExample)
        newExample = ""
    }
}

/// Небольшие капсулы-метки в ряд с переносом.
struct FlowPills: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.ash)
                    .padding(.horizontal, 10).frame(height: 28)
                    .overlay(Capsule().stroke(AppColor.hairline))
            }
        }
    }
}

/// Фоновая сетка точек, затухающая вниз.
struct DotGridBackdrop: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 4
            while y < size.height {
                var x: CGFloat = 4
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(AppColor.ink.opacity(0.12)))
                    x += 14
                }
                y += 14
            }
        }
        .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
