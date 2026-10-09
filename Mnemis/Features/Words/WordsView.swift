import SwiftUI
import SwiftData
import MnemisCore

/// Личный словарь: поиск, список слов, добавление (ABOUT.md, раздел 15).
struct WordsView: View {
    @Query(sort: \Word.lemma) private var words: [Word]
    @Query private var examples: [UserExample]
    @Query private var notes: [UserNote]
    @State private var query = ""
    @State private var isAdding = false

    private var userTexts: [UUID: [String]] {
        var result: [UUID: [String]] = [:]
        for example in examples {
            result[example.wordID, default: []].append(example.text)
        }
        for note in notes {
            result[note.wordID, default: []].append(note.text)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(SearchService.search(query, in: words, userTexts: userTexts)) { word in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(word.lemma)
                        if !word.translation.isEmpty {
                            Text(word.translation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search words")
            .navigationTitle("Words")
            .toolbar {
                Button("Add Word", systemImage: "plus") {
                    isAdding = true
                }
            }
            .sheet(isPresented: $isAdding) {
                AddWordView()
            }
            .overlay {
                if words.isEmpty {
                    ContentUnavailableView(
                        "No words yet",
                        systemImage: "character.book.closed",
                        description: Text("Tap + to add your first word.")
                    )
                }
            }
        }
    }
}

/// Добавление слова вручную. Работает офлайн: перевод и определение можно дополнить позже.
private struct AddWordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var lemma = ""
    @State private var translation = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Word", text: $lemma)
                    .textInputAutocapitalization(.never)
                TextField("Translation (optional)", text: $translation)
            }
            .navigationTitle("New Word")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(lemma.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        context.insert(Word(
            lemma: lemma.trimmingCharacters(in: .whitespaces),
            translation: translation.trimmingCharacters(in: .whitespaces),
            origin: .user,
            source: "user",
            license: "user-generated"
        ))
        dismiss()
    }
}
