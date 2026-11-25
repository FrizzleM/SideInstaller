import SwiftUI

/// The install history: every successful one-click install, newest first.
/// Read-only — entries are written by `Engine.finishSuccess` and never
/// edited here.
struct InstallHistoryView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer

    @State private var entries: [InstallHistoryEntry] = []

    var body: some View {
        List {
            if entries.isEmpty {
                Text(L("No installs yet."))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: entry.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(entry.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)
                        .locale(Localizer.locale)))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                    Text(verbatim: entry.identity)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L("Install history"))
        .navigationBarTitleDisplayMode(.inline)
        .task { entries = InstallHistoryStore.load() }
    }
}
