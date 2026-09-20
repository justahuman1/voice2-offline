import SwiftUI

struct VocabularyView: View {
    var vocabulary: TextReplacements = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Correct words and phrases that Speak2 commonly mistranscribes. Matches ignore capitalization, punctuation, and extra spacing. Separate alternatives with |, for example: Ty K V | Ty KV | Thai KV.")
                .foregroundStyle(.secondary)

            HStack {
                Text("When Speak2 hears")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Replace with")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: 24, height: 1)
            }
            .font(.headline)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vocabulary.entries) { entry in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                TextField("Phrase, or alternatives separated by |", text: phraseBinding(for: entry))
                                if vocabulary.isDuplicate(entry.id) {
                                    Text("Duplicate phrase")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            TextField("Desired replacement", text: replacementBinding(for: entry))
                                .frame(maxWidth: .infinity)

                            Button(role: .destructive) {
                                vocabulary.deleteEntry(id: entry.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete vocabulary entry")
                        }
                    }
                }
            }

            if let error = vocabulary.persistenceError {
                Text("Could not save vocabulary: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button {
                    vocabulary.addEntry()
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                Spacer()
                Text("Changes are saved automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .onAppear {
            try? vocabulary.reload()
        }
    }

    private func phraseBinding(for entry: TextReplacementEntry) -> Binding<String> {
        Binding(
            get: { vocabulary.entries.first(where: { $0.id == entry.id })?.phrase ?? "" },
            set: { vocabulary.updateEntry(id: entry.id, phrase: $0) }
        )
    }

    private func replacementBinding(for entry: TextReplacementEntry) -> Binding<String> {
        Binding(
            get: { vocabulary.entries.first(where: { $0.id == entry.id })?.replacement ?? "" },
            set: { vocabulary.updateEntry(id: entry.id, replacement: $0) }
        )
    }
}
