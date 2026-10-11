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
                    if viewModel.word.isIdiom {
                        idiomStatusCard
                    } else if viewModel.canPlace {
                        studyCard
                    } else {
                        memoryCard
                    }
                    meaning
                    examples
                    noteSection
                    if !viewModel.word.isIdiom { sources }
                    actions
                    // Идиому удаляют в «Edit»: на карточке внизу те же кнопки, что у слова (холст: Idiom-Details).
                    if viewModel.word.origin == .user, !viewModel.word.isIdiom {
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
        .sheet(isPresented: $isEditing) { EditWordView(viewModel: viewModel, onDeleted: { dismiss() }) }
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
                        .font(.system(size: viewModel.word.isIdiom ? 38 : 46, weight: .semibold)).tracking(-1.6)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    if let ipa = viewModel.word.ipa {
                        Text(ipa).font(.system(size: 15, design: .monospaced)).foregroundStyle(AppColor.ash)
                    }
                }
                Spacer()
                SpeakButton(text: viewModel.word.lemma)
            }
            FlowPills(items: viewModel.word.isIdiom ? idiomPills : pills)
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

    /// Карточка не начатого слова (холст: Word-Study): плитки «Today / Practice / Later» вместо метрик.
    private var studyCard: some View {
        let placement = viewModel.placement
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Group {
                        if placement == nil {
                            Circle().stroke(AppColor.smoke, lineWidth: 1.5)
                        } else {
                            Circle().fill(AppColor.fill)
                        }
                    }
                    .frame(width: 10, height: 10)
                    Text(studyTitle(placement)).font(.system(size: 16, weight: .medium))
                }
                Spacer()
                MemoryBar(level: 0)
            }
            Text("[ add to study ]").bracketLabel()
            HStack(spacing: 8) {
                ForEach(StudyPlacement.allCases) { option in
                    StudyTile(option: option, isOn: placement == option) {
                        withAnimation(Motion.swap) { viewModel.togglePlacement(option) }
                    }
                }
            }
            Text(studyHint(placement))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColor.smoke)
        }
        .foregroundStyle(AppColor.ink)
        .padding(.horizontal, 26).padding(.top, 18).padding(.bottom, 20)
        .glassCard()
        .cornerMarks()
    }

    private func studyTitle(_ placement: StudyPlacement?) -> LocalizedStringKey {
        switch placement {
        case nil: "Not started"
        case .today?: "In today's deck"
        case .practice?: "In Practice"
        case .later?: "Learning from tomorrow"
        }
    }

    private func studyHint(_ placement: StudyPlacement?) -> String {
        switch placement {
        case nil: String(localized: "not started · extra words are fine")
        case .today?: String(localized: "in deck · \(viewModel.newToday) / \(viewModel.newLimit) new · tap to undo")
        case .practice?: String(localized: "in Practice · tap to undo")
        case .later?: String(localized: "first review tomorrow · tap to undo")
        }
    }

    private var idiomPills: [String] {
        var result = ["idiom", viewModel.status.rawValue]
        if viewModel.word.origin == .user { result.append("yours") }
        return result
    }

    /// Карточка статуса идиомы (холст: Idiom-Study): этап, плитки «Today / Practice / Later» пока идиому не повторяли
    /// и метрики, когда она уже в изучении.
    private var idiomStatusCard: some View {
        let placement = viewModel.placement
        let showsTiles = viewModel.canPlace
        let showsMetrics = viewModel.status != .new && placement == nil
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Group {
                        if placement != nil || viewModel.status == .known {
                            Circle().fill(AppColor.fill)
                        } else {
                            Circle().stroke(AppColor.smoke, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 10, height: 10)
                    idiomTitle(placement).font(.system(size: 16, weight: .medium))
                }
                Spacer()
                if viewModel.status == .known {
                    Text("✓").font(.system(size: 13, design: .monospaced)).foregroundStyle(AppColor.accent)
                }
            }
            IdiomStageSwitch(selection: viewModel.status) { viewModel.setStatus($0) }
            if showsTiles {
                Text("[ add to study ]").bracketLabel()
                HStack(spacing: 8) {
                    ForEach(StudyPlacement.allCases) { option in
                        StudyTile(option: option, isOn: placement == option) {
                            withAnimation(Motion.swap) { viewModel.togglePlacement(option) }
                        }
                    }
                }
            }
            if showsMetrics {
                HStack {
                    metric(nextText, "next review")
                    metric(intervalText, "interval")
                    metric("\(viewModel.progress?.correctCount ?? 0) / \(viewModel.progress?.incorrectCount ?? 0)", "right / wrong")
                }
            }
            Text(placement == nil ? idiomHint : studyHint(placement))
                .font(.system(size: viewModel.status == .new || placement != nil ? 11 : 12, design: .monospaced))
                .foregroundStyle(AppColor.smoke)
        }
        .foregroundStyle(AppColor.ink)
        .padding(.horizontal, 26).padding(.vertical, 20)
        .glassCard()
        .cornerMarks()
    }

    private func idiomTitle(_ placement: StudyPlacement?) -> Text {
        if let placement { return Text(studyTitle(placement)) }
        return viewModel.status == .known ? Text("You know this idiom") : Text(statusTitle)
    }

    private var idiomHint: String {
        let days = Int((viewModel.progress?.intervalDays ?? 0).rounded())
        switch viewModel.status {
        case .new: return String(localized: "not started · extra idioms are fine")
        case .learning: return days <= 1 ? "still learning · back tomorrow" : "still learning · back in \(days) d"
        case .reviewing: return "recalled sometimes · next in \(days) d"
        case .remembered: return "known well · next in \(days) d"
        case .known: return "known · rarely comes back"
        case .suspended: return "suspended · not in the queue"
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
            HStack {
                Text("[ meaning ]").bracketLabel()
                Spacer()
                DictionaryLinkButton(term: viewModel.word.lemma)
            }
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
        // Пилюли переносятся на следующую строку, а не обрезаются (холст: Word-Details).
        PillFlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.ash)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10).frame(height: 28)
                    .overlay(Capsule().stroke(AppColor.hairline))
            }
        }
    }
}

/// Раскладка «слева направо с переносом»: следующий элемент встаёт в новую строку, если не помещается.
private struct PillFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(in width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (origins, CGSize(width: maxX, height: y + rowHeight))
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

/// Стадии идиомы для переключателя. `new` показываем как «Learning», `suspended` не выбирает ни одну.
private enum IdiomStage: CaseIterable, Identifiable {
    case learning, reviewing, remembered, known

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .learning: "Learning"
        case .reviewing: "Reviewing"
        case .remembered: "Remembered"
        case .known: "Known"
        }
    }

    var status: LearningStatus {
        switch self {
        case .learning: .learning
        case .reviewing: .reviewing
        case .remembered: .remembered
        case .known: .known
        }
    }

    static func matching(_ status: LearningStatus) -> IdiomStage? {
        switch status {
        case .learning: .learning
        case .reviewing: .reviewing
        case .remembered: .remembered
        case .known: .known
        case .new, .suspended: nil
        }
    }
}

/// Переключатель стадий идиомы: четыре равных сегмента на серой дорожке, подложка скользит между ними.
private struct IdiomStageSwitch: View {
    let selection: LearningStatus
    let onSelect: (LearningStatus) -> Void
    @Namespace private var pill

    var body: some View {
        let current = IdiomStage.matching(selection)
        HStack(spacing: 2) {
            ForEach(IdiomStage.allCases) { stage in
                let selected = current == stage
                Button {
                    guard !selected else { return }
                    withAnimation(Motion.swap) { onSelect(stage.status) }
                } label: {
                    Text(stage.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selected ? AppColor.ink : AppColor.ash)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background {
                            if selected {
                                Capsule().fill(AppColor.segmentActive).matchedGeometryEffect(id: "idiom-stage", in: pill)
                            }
                        }
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(AppColor.track, in: .capsule)
    }
}

/// Плитка выбора размещения слова: значок-плюс, заголовок и короткая подпись. Выбранная — с галочкой.
private struct StudyTile: View {
    let option: StudyPlacement
    let isOn: Bool
    let action: () -> Void

    private var title: LocalizedStringKey {
        switch option {
        case .today: "Today"
        case .practice: "Practice"
        case .later: "Later"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch option {
        case .today: "+1 card"
        case .practice: "exercises"
        case .later: "tomorrow"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Image(systemName: isOn ? "checkmark" : "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? AppColor.onFill : AppColor.ash)
                    .frame(width: 30, height: 30)
                    .background(isOn ? AppColor.fill : .clear, in: .circle)
                    .overlay(Circle().stroke(isOn ? AppColor.fill : AppColor.glassLine))
                    .padding(.bottom, 6)
                Text(title).font(.system(size: 15, weight: .medium))
                Text(subtitle).font(.system(size: 11, design: .monospaced)).foregroundStyle(isOn ? AppColor.ash : AppColor.smoke)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 10)
            .background(isOn ? AppColor.accent.opacity(0.12) : .clear, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isOn ? AppColor.accent : AppColor.glassLine))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
