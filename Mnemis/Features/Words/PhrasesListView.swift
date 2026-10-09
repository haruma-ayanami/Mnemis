import SwiftUI

/// Список идиом во вкладке «Idioms»: поиск и свайп для удаления.
struct PhrasesListView: View {
    @Bindable var viewModel: PhrasesViewModel
    /// Источник «зума» для карточки идиомы: пространство имён экрана Words, где идёт переход.
    let zoom: Namespace.ID
    var onAdd: () -> Void
    var onOpen: (Phrase) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField.padding(.top, 14)
            content
        }
        .onAppear { viewModel.load() }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppColor.smoke)
            TextField("Search idioms and meanings", text: $viewModel.query)
                .textFieldStyle(.plain)
                .mnemisNoAutocapitalization()
                .foregroundStyle(AppColor.ink)
        }
        .font(.system(size: 16))
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
        .glassCapsule()
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LoadingView()
        case .failed(let message):
            ErrorStateView(message: message)
        case .loaded:
            if viewModel.totalCount == 0 {
                EmptyStateView(
                    title: "No idioms yet",
                    systemImage: "text.quote",
                    message: "Save an idiom you want to remember. Its meaning comes from Wiktionary, and it shows up in Today.",
                    actionTitle: "Add idiom",
                    action: onAdd
                )
            } else if viewModel.phrases.isEmpty {
                VStack(spacing: 12) {
                    Text("┌─────────┐\n│  · · ·  │\n└─────────┘")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(AppColor.faint)
                    Text("Nothing found").font(.system(size: 17, weight: .medium)).foregroundStyle(AppColor.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                Spacer()
            } else {
                List {
                    ForEach(viewModel.phrases) { phrase in
                        Button { onOpen(phrase) } label: {
                            PhraseRow(phrase: phrase).matchedTransitionSource(id: phrase.id, in: zoom)
                        }
                            .buttonStyle(PressScaleStyle())
                            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(AppColor.hairline)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { viewModel.toggleKnown(phrase) } label: {
                                    Label(phrase.isKnown ? "Learning" : "I know", systemImage: phrase.isKnown ? "arrow.uturn.backward" : "checkmark")
                                }
                                .tint(AppColor.accent)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { viewModel.delete(phrase) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(.top, 8)
            }
        }
    }
}

private struct PhraseRow: View {
    let phrase: Phrase

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.text)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppColor.ink)
                    .multilineTextAlignment(.leading)
                Text(phrase.meaning)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.ash)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Text(phrase.isKnown ? "known" : "idiom")
                .font(.system(size: 10, design: .monospaced))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(phrase.isKnown ? AppColor.smoke : AppColor.accent)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(Capsule().stroke(phrase.isKnown ? AppColor.hairline : AppColor.accent.opacity(0.5)))
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
