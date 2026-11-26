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
    /// F-3 (0.9.160): true while the reinstall-all loop runs; the
    /// button and the rows stay disabled until it lands.
    @State private var reinstallingAll = false
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
                    reinstallAllFailed()
                } label: {
                    Label(L("Reinstall all"), systemImage: "arrow.clockwise")
                }
                .disabled(!entries.contains(where: { !$0.success }) || reinstallingID != nil || reinstallingAll)
            }
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

    /// F-3 (0.9.160): reinstall every failed entry, one at a time, in
    /// list order. No IPA in Downloads means skip, not fail — the same
    /// `historyIPAURL` matcher the single path uses decides, so the
    /// loop's skip and the row's "download it again" never disagree.
    /// `reinstallFromHistory` returns when its run *starts*, not when it
    /// lands, so each started run is waited out (`Shortcuts.install`
    /// 同款：`isRunning` 落袋再看 `finished`) before the next item
    /// starts — otherwise the next import is refused for a run already
    /// in flight. A run cancelled mid-loop stops the loop; the summary
    /// counts only what actually ran.
    private func reinstallAllFailed() {
        guard reinstallingID == nil, !reinstallingAll else { return }
        let failed = entries.filter { !$0.success }
        guard !failed.isEmpty else { return }
        reinstallingAll = true
        Task { @MainActor in
            var succeeded = 0
            var failedCount = 0
            var skipped = 0
            var failedNames: [String] = []
            for entry in failed {
                if Task.isCancelled { break }
                guard engine.historyIPAURL(for: entry) != nil else {
                    skipped += 1
                    continue
                }
                reinstallingID = entry.id
                let started = await engine.reinstallFromHistory(entry)
                if started {
                    while engine.isRunning, !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                    if Task.isCancelled {
                        reinstallingID = nil
                        break
                    }
                    // installOneCustomIPA 同口径：降级拒绝是单项跳过
                    // （批继续），跑完看 finished，失败只计数、不停批。
                    if engine.downgradeDeclined {
                        failedCount += 1
                        failedNames.append(entry.appName)
                    } else if engine.finished {
                        succeeded += 1
                    } else {
                        failedCount += 1
                        failedNames.append(entry.appName)
                    }
                } else {
                    failedCount += 1
                    failedNames.append(entry.appName)
                }
                reinstallingID = nil
            }
            reinstallingAll = false
            entries = InstallHistoryStore.load()
            var summary = L("Reinstall all finished: %d succeeded, %d failed, %d skipped.", succeeded, failedCount, skipped)
            if !failedNames.isEmpty {
                summary += " " + L("Failed: %@", failedNames.prefix(5).joined(separator: "、"))
            }
            notice = summary
        }
    }
}
