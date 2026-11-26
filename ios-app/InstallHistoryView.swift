import SwiftUI

/// F-1 (0.9.166): the history result filter — the segmented control's
/// selection, file scope so the Picker's tags read it.
private enum HistoryResultFilter {
    case all
    case succeeded
    case failed
}

/// F-3 (0.9.167): the filtered history as a shareable .txt file —
/// SettingsView's `LogExportFile` 同款：a custom Transferable with a
/// `FileRepresentation`, the file written only when the share actually
/// happens. The entries ride in the struct (≤100 short lines); the
/// preview is passed at the ShareLink call site — a custom Transferable
/// has no default preview (0.9.154 修法教训，别自己发明写法）。
private struct HistoryExportFile: Transferable {
    let entries: [InstallHistoryEntry]

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation<HistoryExportFile>(exportedContentType: .plainText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("SideInstaller-history.txt")
            try file.exportText.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url, allowAccessingOriginalFile: false)
        }
    }

    /// One line per entry: title — date — signer — Succeeded/Failed[: reason].
    /// The date style is the row's own (abbreviated + shortened).
    private var exportText: String {
        var lines = [L("Install history")]
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Localizer.locale)
        for entry in entries {
            var line = "\(entry.title) — \(entry.date.formatted(style)) — \(entry.identity) — "
            line += entry.success ? L("Succeeded") : L("Failed")
            if !entry.success, let reason = entry.failureReason, !reason.isEmpty {
                line += ": \(reason)"
            }
            // F-2 (0.9.169): the Bundle ID, so two same-name clones
            // (multi-open) stay distinguishable in the export — the row
            // and the search show it since 0.9.168, the export dropped it.
            if let bundleID = entry.bundleID, !bundleID.isEmpty {
                line += " — \(bundleID)"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}

/// The install history: every successful one-click install, newest first.
/// Tap a row to reinstall it from the IPA still in Downloads (F1, 0.9.148);
/// the toolbar trash empties the list (F3, 0.9.148). Entries are written by
/// `Engine.finishSuccess` and never edited here.
struct InstallHistoryView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @Environment(Engine.self) private var engine

    @State private var entries: [InstallHistoryEntry] = []
    /// F-3 (0.9.165)：历史搜索——标题/签名身份内存过滤（文件页
    /// filteredUnsigned 同款），不碰写入。
    @State private var historySearchText = ""
    /// F-1 (0.9.166)：按结果筛选——全部 / 成功 / 失败，与搜索叠加
    /// 用（`success` 是 F-A 0.9.155 起存的字段）；内存过滤，不碰写入。
    @State private var historyResultFilter: HistoryResultFilter = .all
    /// `id` of the entry whose reinstall is running, if any.
    @State private var reinstallingID: UUID?
    /// F-3 (0.9.160): true while the reinstall-all loop runs; the
    /// button and the rows stay disabled until it lands.
    @State private var reinstallingAll = false
    /// B-2 (0.9.164): the in-flight reinstall (single or all), so a stuck
    /// wait can be cancelled from the toolbar instead of spinning forever.
    /// Cancelling only stops watching — the install itself keeps going on
    /// the Install page.
    @State private var reinstallTask: Task<Void, Never>?
    /// B-2 (0.9.164): how long a reinstall wait runs before giving up on
    /// watching it — the install itself keeps going on the Install page.
    private static let reinstallWaitTimeout: TimeInterval = 600
    /// Failure notice (no matching IPA, or a refused import).
    @State private var notice: String?
    /// Clear-history confirmation: true while the alert stands.
    @State private var confirmingClear = false

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $historySearchText, placeholder: L("搜索"))
                .padding(.horizontal)
                .padding(.top, 8)
            // F-1 (0.9.166)：结果分段——文件页顶部分段同款（`.segmented`），
            // 与上面的搜索叠加过滤。
            Picker("", selection: $historyResultFilter) {
                Text(L("All")).tag(HistoryResultFilter.all)
                Text(L("Succeeded")).tag(HistoryResultFilter.succeeded)
                Text(L("Failed")).tag(HistoryResultFilter.failed)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
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
            ForEach(filteredEntries) { entry in
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
                            // F-1 (0.9.168)：有 Bundle ID 就显示一行——
                            // 两个同名分身的行只有这里能分清，搜到的是哪
                            // 个也一眼可见；老条目没存就不显示。
                            if let bundleID = entry.bundleID, !bundleID.isEmpty {
                                Text(verbatim: bundleID)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                            }
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
                // F-3 (0.9.164): reveal this entry's IPA in Downloads —
                // swipe for it, or long-press the row. The row tap itself
                // still reinstalls.
                .swipeActions(edge: .trailing) {
                    Button {
                        locate(entry)
                    } label: {
                        Label(L("Show in Downloads"), systemImage: "magnifyingglass")
                    }
                    .tint(Theme.accent)
                }
                .contextMenu {
                    Button {
                        locate(entry)
                    } label: {
                        Label(L("Show in Downloads"), systemImage: "magnifyingglass")
                    }
                }
            }
        }
        .listStyle(.plain)
        }
        .navigationTitle(L("Install history"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // B-2 (0.9.164): the wait's only way out while a run hangs
                // (no Wi-Fi mid-run, an unanswered 2FA prompt) — the run
                // itself keeps going on the Install page.
                if reinstallingID != nil || reinstallingAll {
                    Button(L("Cancel")) { reinstallTask?.cancel() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                // F-3 (0.9.167): export the filtered list (same result filter
                // + search as the rows on screen) as a .txt file — preview
                // 是必填的：自定义 Transferable 没有默认预览
                // （LogExportFile 同款，0.9.154 教训）。空列表时禁用。
                ShareLink(item: HistoryExportFile(entries: filteredEntries),
                          preview: SharePreview(L("Export history"), image: Image(systemName: "doc.text"))) {
                    Label(L("Export history"), systemImage: "square.and.arrow.up")
                }
                .disabled(filteredEntries.isEmpty)
            }
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

    /// F-3 (0.9.165)：标题或签名身份命中即留。
    /// F-1 (0.9.168)：Bundle ID 也可搜——0.9.168 起的条目都存了它，
    /// 同名不同包靠搜 Bundle ID 分清；没存的老条目仍按标题/签名身份搜。
    /// F-1 (0.9.166)：结果筛选先行（`success` 字段），搜索再叠加上去。
    private var filteredEntries: [InstallHistoryEntry] {
        var list = entries
        switch historyResultFilter {
        case .all: break
        case .succeeded: list = list.filter { $0.success }
        case .failed: list = list.filter { !$0.success }
        }
        guard !historySearchText.isEmpty else { return list }
        let query = historySearchText.lowercased()
        return list.filter { entry in
            entry.title.lowercased().contains(query)
                || entry.identity.lowercased().contains(query)
                || (entry.bundleID?.lowercased().contains(query) ?? false)
        }
    }

    /// F-3 (0.9.164): jump to the Downloads tab with this entry's IPA
    /// scrolled to and highlighted — the same `historyIPAURL` matcher the
    /// reinstall uses, so a file the row can find is one the jump lands
    /// on. No matching IPA means a notice, never a silent no-op.
    private func locate(_ entry: InstallHistoryEntry) {
        guard let url = engine.historyIPAURL(for: entry) else {
            // B-1 (0.9.169): `reinstallFromHistory` 同款区分——库里没
            // 有同名 IPA，和库里的同名 IPA 是另一个分身，是两回事。
            if engine.historyMissIsCloneMismatch(for: entry) {
                notice = L("The IPA for %@ in Downloads is a different clone. Its bundle ID doesn't match this history entry. Download this clone's IPA first.", entry.appName)
            } else {
                notice = L("Couldn't find %@ in Downloads. Download it again first.", entry.appName)
            }
            return
        }
        NotificationCenter.default.post(name: Engine.revealDownload, object: nil,
                                        userInfo: ["url": url.path])
    }

    /// F1: reinstall this entry from Downloads — the newest same-name IPA,
    /// or a notice telling the user to download it again first.
    /// B-1 (0.9.161): `reinstallFromHistory` returns when its run *starts*,
    /// not when it lands — the old code re-read the list at once, so the
    /// new entry (written by `finishSuccess` / `recordFailure` when the
    /// run ends) wasn't there yet and the stale failed row stayed, and
    /// `reinstallingID` cleared while the run was still going (spinner
    /// stopped early, and tapping the row again reported a phantom
    /// "already running"). Wait the run out first (`reinstallAllFailed`
    /// 同款：`isRunning` 落袋再看 `finished`), then re-read; the row
    /// stays disabled until it lands.
    private func reinstall(_ entry: InstallHistoryEntry) {
        guard reinstallingID == nil else { return }
        // B-1 (0.9.173): an update-all batch owns the install slot —
        // say so instead of starting a run importCustomIPA would refuse.
        if engine.batchUpdateRunning {
            notice = L("全部更新进行中，等它跑完再重装。")
            return
        }
        reinstallingID = entry.id
        reinstallTask = Task { @MainActor in
            defer { reinstallTask = nil }
            let started = await engine.reinstallFromHistory(entry)
            if Task.isCancelled {
                reinstallingID = nil
                return
            }
            if started {
                // B-2 (0.9.164): bounded wait — the run can hang in
                // `ensureNetwork` (Wi-Fi drops mid-run) or on an
                // unanswered 2FA prompt, and the old loop had no timeout
                // and no handle to cancel it, so the spinner spun forever
                // and every other row stayed blocked behind
                // `reinstallingID`. Ten minutes, then stop watching: the
                // install itself keeps going on the Install page.
                var waited = 0.0
                while engine.isRunning, !Task.isCancelled, waited < Self.reinstallWaitTimeout {
                    try? await Task.sleep(for: .milliseconds(500))
                    waited += 0.5
                }
                if Task.isCancelled {
                    reinstallingID = nil
                    return
                }
                if waited >= Self.reinstallWaitTimeout, engine.isRunning {
                    notice = L("Still installing — check the Install page for progress.")
                    reinstallingID = nil
                    return
                }
                // A run that ended writes its entry either way (success via
                // finishSuccess, failure via recordFailure) — re-read
                // unconditionally, so the new row replaces the stale one.
                entries = InstallHistoryStore.load()
                if engine.downgradeDeclined {
                    notice = engine.downgradeDeclinedMessage ?? engine.lastError
                } else if !engine.finished, let error = engine.lastError {
                    notice = error
                }
            } else if let error = engine.lastError {
                notice = error
            }
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
        // B-1 (0.9.173): 同 reinstall — 批跑时不另起重装。
        if engine.batchUpdateRunning {
            notice = L("全部更新进行中，等它跑完再重装。")
            return
        }
        reinstallingAll = true
        reinstallTask = Task { @MainActor in
            defer { reinstallTask = nil }
            var succeeded = 0
            var failedCount = 0
            var skipped = 0
            var failedNames: [String] = []
            // B-2 (0.9.164): a wait that outruns the timeout stops the
            // loop — the run keeps going on the Install page, so the
            // summary gives way to that notice instead.
            var timedOut = false
            for entry in failed {
                if Task.isCancelled { break }
                guard engine.historyIPAURL(for: entry) != nil else {
                    skipped += 1
                    continue
                }
                reinstallingID = entry.id
                let started = await engine.reinstallFromHistory(entry)
                if Task.isCancelled {
                    reinstallingID = nil
                    break
                }
                if started {
                    var waited = 0.0
                    while engine.isRunning, !Task.isCancelled, waited < Self.reinstallWaitTimeout {
                        try? await Task.sleep(for: .milliseconds(500))
                        waited += 0.5
                    }
                    if Task.isCancelled {
                        reinstallingID = nil
                        break
                    }
                    if waited >= Self.reinstallWaitTimeout, engine.isRunning {
                        timedOut = true
                        reinstallingID = nil
                        break
                    }
                    // installOneCustomIPA 同口径：降级拒绝是单项跳过
                    // （批继续），跑完看 finished，失败只计数、不停批。
                    // B-3 (0.9.166)：注释一直说“跳过”，代码却记了失败——
                    // 拒绝降级是用户主动不要装，记 skipped，不记失败、不进
                    // Failed 名单（缺 IPA 的项走同一个桶）。
                    if engine.downgradeDeclined {
                        skipped += 1
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
            if timedOut {
                notice = L("Still installing — check the Install page for progress.")
                return
            }
            var summary = L("Reinstall all finished: %d succeeded, %d failed, %d skipped.", succeeded, failedCount, skipped)
            if !failedNames.isEmpty {
                summary += " " + L("Failed: %@", failedNames.prefix(5).joined(separator: "、"))
            }
            notice = summary
        }
    }
}
