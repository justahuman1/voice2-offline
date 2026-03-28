import SwiftUI

struct StatsView: View {
    var stats: TranscriptionStats = .shared

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Usage Statistics")
                .font(.system(size: 16, weight: .bold))

            Text("\(stats.totalTranscriptions)")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Color.accentColor)

            Text("Total Transcriptions")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            stats.load()
        }
    }
}
