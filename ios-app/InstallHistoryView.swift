import SwiftUI

/// The install history: every successful one-click install, newest first.
/// Tap a row to reinstall it from the IPA still in Downloads (F1, 0.9.148);
/// the toolbar trash empties the list (F3, 0.9.148). Entries are written by
/// `Engine.finishSuccess` and never edited here.
struct InstallHistoryView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @Environment(Engine.self) private var engine

    @State private var entries: [InstallHistoryEntry] = []
    /// `id` of the entry whose reinstall is running, if any.
    @State private var reinstallingID: UUID?
    /// Failure notice (no matching IPA, or a refused import).
    @State private var notice: String?
    /// Clear-history confirmation: true while the alert stands.
    @State private var confirmingClear = false

    var body: some View {
        List {
            if entries.isEmpty {
                // U2 (0.9.151): the empty state used to be one bare line;
                // Downloads page empty state 同款：图标 + 主文案 + 一行
                // 引导，告诉用户装好的会记在这里。
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(Theme.muted)
                    Text(L("No installs yet."))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    Text(L("Installed apps will be listed here."))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 8)
            }
            ForEach(entries) { entry in
                Button { reinstall(entry) } label: {
                    HStack(spacing: 10) {
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
                            // F-A (0.9.155): a failed run says so in red,
                            // with the reason it stopped — the row still
                            // reinstalls on tap, same as a success.
                            if !entry.success {
                                Text(L("Failed"))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.negative)
                                if let reason = entry.failureReason, !reason.isEmpty {
                                    Text(verbatim: reason)
                                        .font(.footnote)
                                        .foregroundStyle(Theme.negative)
                                        .lineLimit(2)
                                }
                            }
                        }
                        Spacer()
                        if reinstallingID == entry.id {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .disabled(reinstallingID != nil)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L("Install history"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    confirmingClear = true
                } label: {
                    Label(L("Clear"), systemImage: "trash")
                }
                .disabled(entries.isEmpty)
            }
        }
        .task { entries = InstallHistoryStore.load() }
        .alert(L("Clear install history?"), isPresented: $confirmingClear) {
            Button(L("Clear"), role: .destructive) {
                confirmingClear = false
                InstallHistoryStore.clear()
                entries = []
            }
            Button(L("Cancel"), role: .cancel) { confirmingClear = false }
        } message: {
            Text(L("This only clears the list. Installed apps are not affected."))
        }
        .alert(L("Install history"), isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button(L("OK"), role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    /// F1: reinstall this entry from Downloads — the newest same-name IPA,
    /// or a notice telling the user to download it again first.
    private func reinstall(_ entry: InstallHistoryEntry) {
        guard reinstallingID == nil else { return }
        reinstallingID = entry.id
        Task {
            let ok = await engine.reinstallFromHistory(entry)
            if !ok, let error = engine.lastError {
                notice = error
            }
            // B-6 (0.9.158): a successful reinstall writes a new entry at
            // the top — re-read, so it shows without leaving the page.
            if ok { entries = InstallHistoryStore.load() }
            reinstallingID = nil
        }
    }
}
