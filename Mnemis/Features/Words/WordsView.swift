import SwiftUI

/// Личный словарь: вкладки «Words» и «Idioms» на одном списке, поиск, фильтры по статусам,
/// свайпы и карточка строки (ABOUT.md, раздел 15). Идиомы — те же строки с частью речи `idiom`.
struct WordsView: View {
    @State private var viewModel: WordsViewModel
    @State private var section: WordsSection = .words
    @State private var isAdding = false
    @State private var addKind: EntryKind = .word
    /// Открытая карточка: переход без шеврона, как в дизайне строк.
    @State private var openedWord: Word?
    /// Источник «зума» для карточек и формы добавления.
    @Namespace private var zoom
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Строки прежнего раздела на время перехода: список уже перечитан для нового раздела.
    @State private var outgoing: OutgoingRows?
    /// Прогресс перехода: 0 — раздел только что сменили, 1 — переход закончился.
    @State private var transition: CGFloat = 1
    /// Направление перехода: +1 — к «Idioms», −1 — к «Words».
    @State private var direction: CGFloat = 1
    @State private var transitionTask: Task<Void, Never>?
    /// Счётчик «поднять список наверх»: растёт при нажатии на раздел (даже открытый) и на фильтр.
    @State private var topRequest = 0
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: WordsViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    header
                    sectionPicker.padding(.top, 16)
                    searchField.padding(.top, 14)
                    if !viewModel.query.isEmpty {
                        searchHint.padding(.top, 8)
                    }
                    chips.padding(.top, 12)
                    listArea
                }
                .padding(.horizontal, 20)
            }
            .mnemisNavigationBarHidden()
            .navigationDestination(isPresented: Binding(
                get: { openedWord != nil },
                set: { if !$0 { openedWord = nil } }
            )) {
                if let openedWord {
                    WordDetailsView(word: openedWord, container: container, onChange: reloadAll)
                        .navigationTransition(.zoom(sourceID: openedWord.id, in: zoom))
                        .hidesTabBar(container.router)
                }
            }
            .sheet(isPresented: $isAdding, onDismiss: reloadAll) {
                // .id(addKind): начальный вид записи применяется заново при каждом открытии, а не сохраняется от прошлого раза.
                AddEntryView(viewModel: viewModel, container: container, initialLemma: section == .words ? viewModel.query : "", initialKind: addKind) { _ in
                    reloadAll()
                }
                .id(addKind)
                .navigationTransition(.zoom(sourceID: Self.addSource, in: zoom))
            }
            .onAppear(perform: reloadAll)
        }
    }

    private func reloadAll() {
        viewModel.load()
    }

    private static let addSource = "add-entry"

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                titleStack
                Text(subtitle)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
                    .contentTransition(.numericText())
            }
            Spacer()
            if !viewModel.query.isEmpty {
                Text("\(viewModel.results.count.formatted()) results")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
                    .padding(.bottom, 6)
            }
            RoundGlassButton(systemImage: "plus", label: section == .words ? "Add word" : "Add idiom") {
                addKind = section == .words ? .word : .idiom
                isAdding = true
            }
            .matchedTransitionSource(id: Self.addSource, in: zoom)
        }
        .padding(.top, 8)
    }

    private var subtitle: String {
        switch section {
        case .words: "\(viewModel.wordCount.formatted()) in your vocabulary"
        case .idioms: viewModel.idiomCount == 1 ? "1 idiom" : "\(viewModel.idiomCount.formatted()) idioms"
        }
    }

    /// Переключатель «Words | Idioms»: подложка скользит между вкладками.
    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(WordsSection.allCases) { item in
                let selected = section == item
                Button { switchSection(to: item) } label: {
                    HStack(spacing: 7) {
                        Text(item.title)
                        Text(viewModel.total(for: item.kind).formatted())
                            .font(.system(size: 11, design: .monospaced)).opacity(0.7)
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background {
                        if selected {
                            Capsule().fill(AppColor.primary).matchedGeometryEffect(id: "section-pill", in: pill)
                        }
                    }
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .glassCapsule()
    }

    /// Порядок результатов поиска: видно, пока введён запрос (холст: Words-Search).
    private var searchHint: some View {
        Text("exact match first · then starts with · then contains")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(AppColor.smoke)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppColor.smoke)
            TextField(section == .words ? "Search word, translation, note" : "Search idioms and meanings", text: $viewModel.query)
                .textFieldStyle(.plain)
                .mnemisNoAutocapitalization()
                .foregroundStyle(AppColor.ink)
            if !viewModel.query.isEmpty {
                Button { viewModel.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppColor.smoke)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .font(.system(size: 16))
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
        .glassCapsule()
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(nil, "All")
                chip(.learning, "Learning")
                chip(.reviewing, "Reviewing")
                chip(.remembered, "Remembered")
                chip(.known, "Known")
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ status: LearningStatus?, _ title: LocalizedStringKey) -> some View {
        let selected = viewModel.filter == status
        return Button {
            viewModel.filter = status
            topRequest += 1
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Text("\(viewModel.count(for: status))")
                    .font(.system(size: 11, design: .monospaced)).opacity(0.7)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
            .padding(.horizontal, 13).frame(minHeight: 36)
            .background(selected ? AppColor.primary : .clear, in: .capsule)
            .overlay(Capsule().stroke(selected ? .clear : AppColor.hairline))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// Заголовок: текущий раздел приходит снизу, прежний уходит вверх (раскадровка Motion-Segment).
    private var titleStack: some View {
        // Заголовок «катится» на 10 pt за 0.3 s; при Reduce Motion остаётся только затухание.
        let roll: CGFloat = reduceMotion ? 0 : 10
        return ZStack(alignment: .leading) {
            if let outgoing {
                sectionTitle(outgoing.section)
                    .opacity(1 - transition)
                    .offset(y: -direction * roll * transition)
            }
            sectionTitle(section)
                .opacity(transition)
                .offset(y: direction * roll * (1 - transition))
        }
        .animation(reduceMotion ? Motion.reduced : .easeOut(duration: 0.3), value: transition)
    }

    private func sectionTitle(_ value: WordsSection) -> some View {
        Text(value == .words ? "Words" : "Idioms")
            .font(.mnemisTitle).tracking(-0.8).foregroundStyle(AppColor.ink)
    }

    /// Список и строки прежнего раздела поверх него. Старые строки уходят влево, новые приходят справа.
    private var listArea: some View {
        // Старые строки уходят на 36 pt и гаснут за 0.2 s; при Reduce Motion только гаснут.
        let slide: CGFloat = reduceMotion ? 0 : 36
        return ZStack(alignment: .top) {
            if let outgoing {
                VStack(spacing: 0) {
                    ForEach(outgoing.rows, id: \.word.id) { row in
                        WordRow(word: row.word, status: row.status)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .bottom) { Rectangle().fill(AppColor.hairline).frame(height: 1) }
                    }
                }
                .padding(.top, 8)
                .offset(x: -direction * slide * transition)
                .opacity(1 - transition)
                .allowsHitTesting(false)
                .animation(reduceMotion ? Motion.reduced : .easeOut(duration: 0.2), value: transition)
            }
            wordsList
        }
    }

    /// Переход к другому разделу. Список перечитывается сразу, а анимация стартует на следующем кадре,
    /// чтобы новые строки успели появиться в стартовом положении.
    private func switchSection(to target: WordsSection) {
        // Нажатие на уже открытый раздел тоже поднимает список наверх.
        guard target != section else {
            topRequest += 1
            return
        }
        let snapshot = viewModel.results.prefix(8).map { OutgoingRow(word: $0, status: viewModel.status(of: $0)) }
        outgoing = OutgoingRows(section: section, rows: snapshot)
        direction = target == .idioms ? 1 : -1
        viewModel.kind = target.kind
        topRequest += 1
        // Пилюля движется пружиной Motion.swap; остальное анимируется своими модификаторами.
        withAnimation(Motion.swap) { section = target }
        // Стартовое положение ставим без анимации: прошлый переход мог ещё не закончиться.
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { transition = 0 }
        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled else { return }
            transition = 1
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            outgoing = nil
        }
    }

    @ViewBuilder
    private var wordsList: some View {
        switch viewModel.state {
        case .loading:
            LoadingView()
        case .failed(let message):
            ErrorStateView(message: message)
        case .loaded:
            if viewModel.totalCount == 0 {
                emptyState
            } else if viewModel.results.isEmpty {
                VStack(spacing: 12) {
                    Text("┌─────────┐\n│  · · ·  │\n└─────────┘")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(AppColor.faint)
                    Text("Nothing found").font(.system(size: 17, weight: .medium)).foregroundStyle(AppColor.ink)
                    if !viewModel.query.isEmpty, section == .words {
                        Button { addKind = .word; isAdding = true } label: { Text("Add “\(viewModel.query)”") }
                            .buttonStyle(GlassButtonStyle(height: 44))
                            .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, word in
                            Button { openedWord = word } label: {
                                WordRow(word: word, status: viewModel.status(of: word), query: viewModel.query, match: WordsViewModel.match(of: word, query: viewModel.query))
                                    .matchedTransitionSource(id: word.id, in: zoom)
                            }
                            .buttonStyle(PressScaleStyle())
                            .modifier(SlideRow(direction: direction, progress: transition, index: index))
                            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(AppColor.hairline)
                            .onAppear { viewModel.loadMoreIfNeeded(after: word) }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { viewModel.markKnown(word) } label: { Label("I know", systemImage: "checkmark") }
                                    .tint(AppColor.accent)
                            }
                            .swipeActions(edge: .trailing) {
                                if word.origin == .user {
                                    Button(role: .destructive) { viewModel.delete(word) } label: { Label("Delete", systemImage: "trash") }
                                }
                                Button { viewModel.suspend(word) } label: { Label("Suspend", systemImage: "pause") }
                                    .tint(AppColor.smoke)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .padding(.top, 8)
                    .foldsTabBarOnScroll(container.router)
                    .onChange(of: topRequest) { _, _ in
                        guard let first = viewModel.results.first?.id else { return }
                        withAnimation(.smooth(duration: 0.35)) {
                            proxy.scrollTo(first, anchor: .top)
                        }
                    }
                    .onChange(of: container.router.reselectCount) { _, _ in
                        guard container.router.reselectedTab == .words, let first = viewModel.results.first?.id else { return }
                        withAnimation(.smooth(duration: 0.35)) {
                            proxy.scrollTo(first, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch section {
        case .words:
            EmptyStateView(
                title: "No words yet",
                systemImage: "character.book.closed",
                message: "Add your first word. It works offline.",
                actionTitle: "Add Word",
                action: { addKind = .word; isAdding = true }
            )
        case .idioms:
            EmptyStateView(
                title: "No idioms yet",
                systemImage: "text.quote",
                message: "Idioms from the built-in list appear as new words. You can also add your own.",
                actionTitle: "Add idiom",
                action: { addKind = .idiom; isAdding = true }
            )
        }
    }
}

/// Два раздела словаря (ABOUT.md, раздел 9.1).
enum WordsSection: String, CaseIterable, Identifiable {
    case words
    case idioms

    var id: String { rawValue }

    var kind: WordKind { self == .idioms ? .idioms : .words }

    var title: LocalizedStringKey {
        switch self {
        case .words: "Words"
        case .idioms: "Idioms"
        }
    }
}

private struct WordRow: View {
    let word: Word
    let status: LearningStatus
    /// Запрос и способ совпадения: в результатах поиска справа вместо статуса стоит подпись совпадения.
    var query = ""
    var match: SearchMatch?

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(highlighted(word.lemma)).font(.system(size: 17, weight: .medium)).foregroundStyle(AppColor.ink)
                if !word.translation.isEmpty {
                    Text(highlighted(word.translation)).font(.system(size: 13)).foregroundStyle(AppColor.ash).lineLimit(1)
                }
            }
            Spacer()
            if let match {
                matchTag(match)
            } else {
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(status.rawValue).font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColor.smoke)
                        StatusDot(status: status)
                    }
                    if status == .new {
                        EmptyView()
                    } else if status == .known {
                        Text("✓").font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.accent)
                    } else if status == .suspended {
                        Text("‖").font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
                    } else {
                        MemoryBar(level: status.strength)
                    }
                }
            }
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Точное совпадение — тег с рамкой, остальные — просто подпись моноширинным шрифтом.
    @ViewBuilder
    private func matchTag(_ match: SearchMatch) -> some View {
        let exact = match == .exact
        Text(match.label)
            .font(.system(size: 11, weight: exact ? .medium : .regular, design: .monospaced))
            .foregroundStyle(exact ? AppColor.accent : AppColor.smoke)
            .padding(.horizontal, exact ? 7 : 0)
            .frame(height: 22)
            .overlay {
                if exact {
                    RoundedRectangle(cornerRadius: 6).stroke(AppColor.accent.opacity(0.6))
                }
            }
    }

    /// Подсвечивает первое вхождение запроса зелёным (в слове и в переводе).
    private func highlighted(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let needle = query.trimmingCharacters(in: .whitespaces)
        if !needle.isEmpty, let range = result.range(of: needle, options: .caseInsensitive) {
            result[range].foregroundColor = AppColor.accent
        }
        return result
    }
}

/// Строки прежнего раздела на время перехода.
private struct OutgoingRows {
    let section: WordsSection
    let rows: [OutgoingRow]
}

private struct OutgoingRow {
    let word: Word
    let status: LearningStatus
}

/// Строка нового раздела: приходит справа на 36 pt за 0.3 s, первые шесть — с задержкой 20 мс.
/// При Reduce Motion остаётся только затухание.
private struct SlideRow: ViewModifier {
    let direction: CGFloat
    let progress: CGFloat
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(x: reduceMotion ? 0 : direction * 36 * (1 - progress))
            .opacity(progress)
            .animation(reduceMotion ? Motion.reduced : .easeOut(duration: 0.3).delay(Double(min(index, 5)) * 0.02), value: progress)
    }
}
