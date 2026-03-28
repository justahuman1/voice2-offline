import SwiftUI
import AppKit

struct HistoryView: View {
    var history: TranscriptionHistory = .shared

    @State private var showClearAlert = false
    @State private var deleteTargetID: UUID? = nil
    @State private var copiedEntryID: UUID? = nil

    var body: some View {
        VStack {
            if history.entries.isEmpty {
                Spacer()
                Text("No transcription history yet.")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                Spacer()
            } else {
                List {
                    ForEach(history.entries) { entry in
                        historyRow(entry)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Clear History") {
                    showClearAlert = true
                }
                .disabled(history.entries.isEmpty)
            }
            .padding()
        }
        .alert("Clear All History", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                history.clearAll()
            }
        } message: {
            Text("This will permanently delete all transcription history.")
        }
        .alert("Delete Entry", isPresented: Binding(
            get: { deleteTargetID != nil },
            set: { if !$0 { deleteTargetID = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteTargetID = nil }
            Button("Delete", role: .destructive) {
                if let id = deleteTargetID {
                    history.deleteEntry(id: id)
                }
                deleteTargetID = nil
            }
        } message: {
            Text("Are you sure you want to delete this entry?")
        }
        .onAppear {
            history.load()
        }
    }

    @ViewBuilder
    private func historyRow(_ entry: TranscriptionEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.text)
                .lineLimit(3)

            HStack {
                Text(smartTimestamp(entry.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if copiedEntryID == entry.id {
                    Text("Copied!")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Copy") {
                        copyToClipboard(entry.text)
                        showCopiedFeedback(for: entry.id)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                Button("Delete") {
                    deleteTargetID = entry.id
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.red)

                Button("Copy & Close") {
                    copyToClipboard(entry.text)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func showCopiedFeedback(for id: UUID) {
        copiedEntryID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if copiedEntryID == id {
                copiedEntryID = nil
            }
        }
    }

    private func smartTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today \(timeString)"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday \(timeString)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            return "\(dateFormatter.string(from: date)), \(timeString)"
        }
    }
}
