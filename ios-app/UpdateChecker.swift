import Foundation

/// Compares this build's version against `latest_version.txt` in the repo and
/// reveals the Install screen's update banner if that one is newer. Every
/// failure is silent: it only ever means there's nothing to show.
/// 发版铁律：每次发版必须同步改 latest_version.txt 到新版本号，
/// 否则旧版永远不提示、新版误提示（1.5.2 stale 误提示实证：
/// txt 一度停在 1.5.2，比 0.9.x 全线都“新”，恢复调用前必须先
/// 把 txt 改回当前版本）。
@MainActor
final class UpdateChecker: ObservableObject {

    /// Raw contents of the version file on the default branch.
    static let versionFileURL =
        "https://raw.githubusercontent.com/wozofa-ship-it/SideInstaller/main/latest_version.txt"
    /// The install page the banner opens, which carries the OTA links.
    static let installPageURL = "https://github.com/wozofa-ship-it/SideInstaller"
    /// The latest stable release's download for this app's own IPA.
    /// The packaging workflow publishes each version as release `v<version>`
    /// with this asset (0.9.149), so this URL only ever serves the current
    /// release — never an older one, as long as the release gate below
    /// confirms the tag names `latestVersion`.
    static let releaseDownloadURL =
        "https://github.com/wozofa-ship-it/SideInstaller/releases/latest/download/SideInstaller.ipa"
    /// The API that names the latest release and its assets.
    static let latestReleaseAPIURL =
        "https://api.github.com/repos/wozofa-ship-it/SideInstaller/releases/latest"
    /// The asset the release must carry for the self-update to light up.
    static let releaseAssetName = "SideInstaller.ipa"

    /// The newest version GitHub advertises, once fetched.
    @Published private(set) var latestVersion: String?
    /// True once a newer version is found, until the banner is dismissed.
    @Published private(set) var showBanner = false
    /// True only when the latest release's tag names the same version as
    /// `latestVersion` AND it carries the IPA asset: the safety gate for the
    /// About page's self-update (0.9.149). A stale or missing release, or
    /// any fetch failure, leaves this false and the update row stays
    /// static — never install an older build.
    @Published private(set) var updateAssetVerified = false

    /// F-1 (0.9.177): the latest release's notes (the `body` of the release
    /// JSON), taken while the gate runs. Cleared whenever the gate fails
    /// or there is nothing newer — the notes only ever describe a
    /// verified newer release.
    @Published private(set) var releaseNotes: String?

    /// B-1 (0.9.179): why the release gate failed — the banner / About
    /// row tells a network failure apart from a release that is still
    /// being published. Nil when the gate passed or never ran.
    @Published private(set) var gateFailure: ReleaseGateFailure?

    /// F-3 (0.9.179): the verified release IPA's size in bytes (the
    /// `size` of the `SideInstaller.ipa` asset), for the "Update to …
    /// · 28 MB" line. Cleared whenever the gate fails, like
    /// `releaseNotes`.
    @Published private(set) var latestAssetSize: Int?

    /// B-1 (0.9.179): why `verifyReleaseAsset` failed. `.network` is a
    /// fetch / parse failure (including timeout); `.tagMismatch` is a
    /// draft / prerelease / tag that doesn't name `latest`;
    /// `.missingAsset` is a published release whose IPA asset isn't up
    /// yet. The last two mean the release is still being published;
    /// only `.network` means the phone couldn't reach GitHub.
    enum ReleaseGateFailure: Equatable {
        case network
        case tagMismatch
        case missingAsset
    }

    /// B-1 (0.9.177): the version file names a newer version but the
    /// release gate hasn't passed — the release is still being published
    /// (or the gate failed). The banner stays up, but its copy says so
    /// instead of offering an update that isn't verified yet.
    var pendingRelease: Bool {
        guard let latest = latestVersion else { return false }
        return showBanner && Self.isNewer(latest, than: currentVersion) && !updateAssetVerified
    }

    /// B-1 (0.9.179): the pending release is pending because the gate's
    /// network fetch failed — not because the release is still
    /// publishing. The banner and About show the network copy for
    /// this one.
    var pendingReleaseNetworkFailed: Bool {
        pendingRelease && gateFailure == .network
    }

    /// F-1 (0.9.177): the release notes trimmed for the banner / About —
    /// the first 5 lines, at most ~500 characters, markdown shown as
    /// plain text. Nil when there are no notes to show.
    var releaseNotesPreview: String? {
        guard let notes = releaseNotes, !notes.isEmpty else { return nil }
        let lines = notes.split(separator: "\n", omittingEmptySubsequences: false)
        var text = lines.prefix(5).joined(separator: "\n")
        let wasCut = lines.count > 5 || text.count > 500
        if text.count > 500 { text = String(text.prefix(500)) }
        return wasCut ? text + "…" : text
    }

    /// This build's marketing version, e.g. "0.5.0".
    let currentVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"

    /// UserDefaults key for the last check date: the version file changes
    /// every few days at most, so one check a day is enough (S6).
    private static let lastCheckKey = "SIDUpdateCheckerLastCheck"

    /// What a check found. `.skipped` means the daily gate held and no
    /// request went out (only when `force` is false).
    enum CheckResult: Equatable {
        case skipped
        case upToDate
        case newer(String)
        /// B-1 (0.9.177): the version file is newer but the release gate
        /// didn't pass — the release is still being published (or the gate
        /// failed): a newer version is known, but nothing is verified to
        /// install.
        case pendingRelease(String)
        case failed
    }

    /// B-2 (0.9.180): the check in flight, so a second call joins it
    /// instead of running the release gate again and wiping the first
    /// call's verified state (the three call sites — app launch, About,
    /// Install tab — can overlap). The `force` flag records whether the
    /// running check satisfies a forced caller: a forced run satisfies
    /// everyone, a non-forced run only satisfies non-forced callers.
    /// `generation` guards the clear: a forced caller queued behind a
    /// non-forced run installs its own entry after ours finishes, and
    /// our clear must not drop it.
    private var inFlightCheck: (force: Bool, task: Task<CheckResult, Never>)?
    private var inFlightCheckGeneration = 0

    /// Fetch the remote version and reveal the banner if it's newer.
    /// B2 (0.9.142): the stamp is only set once a version was really fetched.
    /// A failed check used to stamp too, so a launch with no network on the
    /// day a new version shipped silenced the banner for the next 24 hours.
    @discardableResult
    func check(force: Bool = false) async -> CheckResult {
        // Join a running check when it satisfies this call.
        if let inFlight = inFlightCheck, inFlight.force || !force {
            return await inFlight.task.value
        }
        // A forced call behind a non-forced run waits for it, then runs
        // its own — never two gates at once. Cancelling the waiter only
        // cancels the wait, never the shared run: awaiting a Task's value
        // neither throws nor cancels the awaited task (same shape as the
        // apps page awaiting `manager.inFlightLoadTask`).
        if let inFlight = inFlightCheck {
            _ = await inFlight.task.value
        }
        inFlightCheckGeneration += 1
        let generation = inFlightCheckGeneration
        let task = Task { [weak self] in
            guard let self else { return CheckResult.failed }
            return await self.performCheck(force: force)
        }
        inFlightCheck = (force: force, task: task)
        let result = await task.value
        if inFlightCheckGeneration == generation { inFlightCheck = nil }
        return result
    }

    /// The check itself, pulled out of `check()` (B-2, 0.9.180) so the
    /// wrapper above can share one run between callers. Behaviour
    /// unchanged.
    private func performCheck(force: Bool) async -> CheckResult {
        // One check a day: skip when the last successful check was recent.
        // A failed check stamps nothing, so the next launch tries again.
        let now = Date()
        if !force,
           let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date,
           now.timeIntervalSince(last) < 24 * 3600 { return .skipped }
        guard let url = URL(string: Self.versionFileURL) else { return .failed }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        // B5 (0.9.146): 15 seconds, not URLSession's 60-second default, so a
        // manual check on a weak network fails fast instead of sitting on
        // "Checking for updates…" for a minute.
        req.timeoutInterval = 15
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let body = String(data: data, encoding: .utf8) else { return .failed }

        let latest = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latest.isEmpty else { return .failed }
        // B-3 (0.9.179): snapshot the verified state before the gate
        // runs — a failed or cancelled re-check must not strip an
        // update that was already verified (the "Update now" button
        // and the About pill would vanish until the next successful
        // check). Taken BEFORE `latestVersion` is overwritten, so
        // `wasLatest` is the version the verified state belongs to;
        // restored below only when it names the same version — a
        // newer version file names a different release, and the old
        // verified state is stale for it (restoring it would offer
        // an update the gate never verified).
        let wasVerified = updateAssetVerified
        let wasLatest = latestVersion
        let wasNotes = releaseNotes
        let wasSize = latestAssetSize
        latestVersion = latest
        showBanner = Self.isNewer(latest, than: currentVersion)
        // The release gate only runs when there is something newer: a
        // second request on every launch would be pure cost. A failed
        // gate leaves the banner as it is — the banner only opens a web
        // page — but the About row stays static.
        // B5 (0.9.153): the daily stamp is only set once the gate has
        // passed — or there is nothing newer to gate. A failed gate used
        // to stamp too, so the About row stayed static for the next 24
        // hours even though the release never verified. The "up to date"
        // stamp is unchanged: no gate runs, nothing to fail.
        let verified = showBanner ? await verifyReleaseAsset(for: latest) : true
        if showBanner, !verified, wasVerified, wasLatest == latest {
            updateAssetVerified = true
            releaseNotes = wasNotes
            latestAssetSize = wasSize
            gateFailure = nil
            return .newer(latest)
        }
        updateAssetVerified = showBanner ? verified : false
        // F-1 (0.9.177): no newer version, no notes to show. (When the
        // gate runs, `verifyReleaseAsset` clears them itself on failure
        // and fills them on success.)
        // F-3 (0.9.179): same for the asset size and the gate failure —
        // with nothing newer there is no gate outcome to keep.
        if !showBanner { releaseNotes = nil; latestAssetSize = nil; gateFailure = nil }
        // B-1 (0.9.177): the version file is newer but the release gate
        // didn't pass — report it as pending, not as a verified newer
        // version. `latestVersion` stays set and `updateAssetVerified`
        // stays false, and the daily stamp is NOT set here (B5, 0.9.153:
        // the stamp only lands below, once the gate has passed or there
        // is nothing newer to gate), so the next launch retries the gate.
        guard verified else { return .pendingRelease(latest) }
        UserDefaults.standard.set(now, forKey: Self.lastCheckKey)
        return showBanner ? .newer(latest) : .upToDate
    }

    /// Checks the latest release against `latest`: it must be a formal
    /// release (not a draft or prerelease), its tag must name exactly that
    /// version, and its assets must include `SideInstaller.ipa`.
    /// Fails closed — any fetch or parse failure returns false.
    /// B-1 (0.9.179): the failure leaves its reason in `gateFailure`,
    /// so the banner / About can tell a network failure apart from a
    /// release that is still being published.
    private func verifyReleaseAsset(for latest: String) async -> Bool {
        // F-1 (0.9.177): the notes only describe a verified release —
        // clear them first; a failed gate leaves nothing behind.
        // F-3 (0.9.179): same for the asset size.
        releaseNotes = nil
        latestAssetSize = nil
        gateFailure = nil
        guard let url = URL(string: Self.latestReleaseAPIURL) else {
            gateFailure = .network
            return false
        }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        // Same 15-second bound as the version check (B5, 0.9.146).
        req.timeoutInterval = 15
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = json["assets"] as? [[String: Any]] else {
            gateFailure = .network
            return false
        }
        // B-1 (0.9.179): a draft / prerelease / wrong tag means the
        // release for this version isn't published yet — not a network
        // problem.
        guard (json["draft"] as? Bool) == false,
              (json["prerelease"] as? Bool) == false,
              let tag = json["tag_name"] as? String else {
            gateFailure = .tagMismatch
            return false
        }
        // The tag names the version with a "v" in front ("v0.9.149").
        let tagVersion = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        // Equal, not just newer: a release for another version — older or
        // newer than the version file — is not the one to install.
        guard !Self.isNewer(tagVersion, than: latest), !Self.isNewer(latest, than: tagVersion) else {
            gateFailure = .tagMismatch
            return false
        }
        // F-3 (0.9.179): keep the IPA asset's size for the update line.
        // B-1 (0.9.179): a release without its IPA asset yet is still
        // being published.
        guard let asset = assets.first(where: { ($0["name"] as? String) == Self.releaseAssetName }) else {
            gateFailure = .missingAsset
            return false
        }
        latestAssetSize = asset["size"] as? Int
        // F-1 (0.9.177): the gate passed — keep the release notes for
        // the banner / About "What's new".
        let body = (json["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        releaseNotes = (body?.isEmpty == false) ? body : nil
        return true
    }

    /// Close the banner for this launch.
    func dismiss() { showBanner = false }

    // MARK: - Self-update

    /// F-1 (0.9.176): the self-update's state lives here now, not in
    /// `AboutView` — the Install tab's update banner runs the same
    /// pipeline from the same state (one run, one progress line, one
    /// error), and the About row only reads it. Moved verbatim from
    /// `AboutView.startSelfUpdate` (0.9.148–0.9.173); `engine` there
    /// was the shared instance too.
    /// True from the update tap until its run ends (or it fails to start).
    @Published var isSelfUpdating = false
    /// Set once this launch's self-update installed: the row goes back to
    /// static text instead of offering the same version again.
    @Published var selfUpdateFinished = false
    /// Why the last self-update didn't start, shown under "Check for updates".
    @Published var selfUpdateError: String?
    /// The in-flight self-update, so its state survives redraws.
    private var selfUpdateTask: Task<Void, Never>?
    /// B-2 (0.9.164): how long the self-update wait runs before giving up
    /// on watching it — the install itself keeps going on the Install page.
    /// B-3 (0.9.178): now the shared `Engine.installSlotWaitTimeout`
    /// (10 minutes), so every slot wait bounds the same way.
    private static let selfUpdateWaitTimeout = Engine.installSlotWaitTimeout

    /// True when a newer version is confirmed AND its release asset is
    /// verified: the only state in which the version row (or the banner)
    /// installs anything. Independent of the Install tab's banner —
    /// dismissing that must not hide the update here. Never true after
    /// this launch's self-update already installed.
    var selfUpdateAvailable: Bool {
        guard !selfUpdateFinished, let latest = latestVersion else { return false }
        return Self.isNewer(latest, than: currentVersion) && updateAssetVerified
    }

    /// What the self-update is doing: the download percent, or "Installing"
    /// once the run starts. Nil when no self-update is running.
    var selfUpdateProgressText: String? {
        guard isSelfUpdating else { return nil }
        let engine = Engine.shared
        if engine.isRunning { return L("Installing") }
        return L("Downloading… %d%%", Int((engine.importProgress ?? 0) * 100))
    }

    /// While a self-update runs the row (or the banner) cancels it instead
    /// (B-2, 0.9.164) — the install itself keeps going on the Install
    /// page; only the watching stops.
    func cancelSelfUpdate() {
        selfUpdateTask?.cancel()
    }

    /// Downloads the verified release IPA into the custom slot and runs the
    /// one-click pipeline on it (reinstallFromHistory 同款，0.9.148):
    /// no separate self-update path. The Install sheet comes forward
    /// (F4 同款 sharedIPAReady) so the run's progress is in front of the
    /// user; a refusal leaves its reason on this page instead of failing
    /// silently.
    func startSelfUpdate() {
        guard selfUpdateAvailable, !isSelfUpdating else { return }
        let engine = Engine.shared
        // B-1 (0.9.173): an update-all batch owns the install slot —
        // the self-update's import would be refused mid-batch; say so
        // instead of failing silently.
        if engine.batchUpdateRunning {
            selfUpdateError = L("全部更新进行中，等它跑完再更新。")
            return
        }
        selfUpdateError = nil
        selfUpdateFinished = false
        isSelfUpdating = true
        selfUpdateTask = Task {
            // F-1 (0.9.179): the download phase is shared with the
            // enterprise branch (`downloadSelfUpdateIPA`).
            guard await downloadSelfUpdateIPA() != nil else {
                isSelfUpdating = false
                selfUpdateTask = nil
                return
            }
            // B-39-B2 同款 (0.9.148): the source is only switched once the
            // import really landed, so a refused import can't retarget a
            // pipeline that's already running.
            engine.installSource = .custom
            engine.runOneClick()
            // Shortcuts.install 同款：等管线起跑再认成功；起不来时把原因
            // 留在检查行里，不静默、不开空的安装页。
            var waited = 0.0
            while !engine.isRunning, !Task.isCancelled, waited < 3.0 {
                try? await Task.sleep(for: .milliseconds(100))
                waited += 0.1
            }
            if Task.isCancelled {
                isSelfUpdating = false
                selfUpdateTask = nil
                return
            }
            if engine.isRunning {
                engine.sharedIPAReady = true
                // Wait the run out so the row doesn't offer the same update
                // again while it installs; the floating Install pill carries
                // the progress meanwhile.
                // B-2 (0.9.164): bounded — the run can hang in
                // `ensureNetwork` (Wi-Fi drops mid-run) or on an
                // unanswered 2FA prompt, and the old loop had no timeout
                // and the row refused taps while it ran, so the page sat
                // on "Installing" forever. Ten minutes, then stop watching:
                // the install itself keeps going on the Install page.
                var waited = 0.0
                while engine.isRunning, !Task.isCancelled, waited < Self.selfUpdateWaitTimeout {
                    try? await Task.sleep(for: .seconds(1))
                    waited += 1
                }
                if Task.isCancelled {
                    isSelfUpdating = false
                    selfUpdateTask = nil
                    return
                }
                if waited >= Self.selfUpdateWaitTimeout, engine.isRunning {
                    selfUpdateError = L("Still installing — check the Install page for progress.")
                    isSelfUpdating = false
                    selfUpdateTask = nil
                    return
                }
                if engine.finished {
                    selfUpdateFinished = true
                }
            } else if let guide = engine.guide {
                // B-2 (0.9.163): 向导优先于 lastError——runOneClick 入口
                // 已清掉上一跑的 lastError/guide，剩下的向导就是这次
                // 起跑守卫拦住的真原因（没账号/没配对文件），不再先报
                // lastError 里的上一跑旧错。
                selfUpdateError = guide.title
            } else if let error = engine.lastError {
                selfUpdateError = error
            }
            isSelfUpdating = false
            selfUpdateTask = nil
        }
    }

    /// F-1 (0.9.179): the download phase shared by the self-update's two
    /// branches — re-checks the gate at tap time, downloads the verified
    /// release IPA into the custom slot, and returns its staged URL.
    /// Sets `selfUpdateError` on failure; does NOT touch
    /// `isSelfUpdating` (the caller owns the run flag and its task).
    func downloadSelfUpdateIPA() async -> URL? {
        // Re-check the gate at tap time: still newer, still verified.
        guard let latest = latestVersion,
              updateAssetVerified,
              Self.isNewer(latest, than: currentVersion) else { return nil }
        let engine = Engine.shared
        // B-1 (0.9.173): an update-all batch owns the install slot —
        // the self-update's import would be refused mid-batch; say so
        // instead of failing silently. `startSelfUpdate` checks this
        // before spawning its task too; the race between the two is
        // covered here.
        if engine.batchUpdateRunning {
            selfUpdateError = L("全部更新进行中，等它跑完再更新。")
            return nil
        }
        let ok = await engine.importCustomIPA(fromLink: Self.releaseDownloadURL)
        if Task.isCancelled { return nil }
        guard ok else {
            selfUpdateError = engine.lastError
            return nil
        }
        // B-2 (0.9.178): re-check the batch guard AFTER the import —
        // the tap-time guard above passed, but an update-all batch
        // may have started during the download; starting the run now
        // would steal its slot. Say so (the tap-time reason) instead
        // of running into it.
        if engine.batchUpdateRunning {
            selfUpdateError = L("全部更新进行中，等它跑完再更新。")
            return nil
        }
        guard let staged = IPALibrary.customImport() else {
            selfUpdateError = engine.lastError ?? L("Import failed")
            return nil
        }
        return staged.url
    }

    /// F-1 (0.9.179): the enterprise branch of the self-update choice —
    /// downloads the verified IPA like `startSelfUpdate`, then hands its
    /// staged URL to `onDownloaded` (the view forwards it to
    /// `CertWorkspace`, which opens the signing page) instead of running
    /// the Apple ID pipeline. The run flag and task are owned here, so
    /// the pill's cancel works while the download runs.
    func startSelfUpdateEnterprise(onDownloaded: @escaping @MainActor (URL) -> Void) {
        guard selfUpdateAvailable, !isSelfUpdating else { return }
        let engine = Engine.shared
        if engine.batchUpdateRunning {
            selfUpdateError = L("全部更新进行中，等它跑完再更新。")
            return
        }
        selfUpdateError = nil
        selfUpdateFinished = false
        isSelfUpdating = true
        selfUpdateTask = Task {
            guard let url = await downloadSelfUpdateIPA() else {
                isSelfUpdating = false
                selfUpdateTask = nil
                return
            }
            isSelfUpdating = false
            selfUpdateTask = nil
            await onDownloaded(url)
        }
    }

    /// Compare dotted versions numerically, so "0.10.0" > "0.9.0". Anything
    /// after a "-" (e.g. "-beta.1") is ignored.
    /// B-1 note (0.9.177): that also makes a beta tag compare equal to its
    /// formal version ("0.9.177-beta.1" == "0.9.177") — noted, deliberately
    /// not fixed this round.
    nonisolated static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        func parts(_ v: String) -> [Int] {
            let core = v.split(separator: "-", maxSplits: 1).first ?? ""
            return core.split(separator: ".").map { Int($0) ?? 0 }
        }
        let a = parts(lhs)
        let b = parts(rhs)
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
