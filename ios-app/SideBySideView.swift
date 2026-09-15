import SwiftUI
import SideInstallerFFI

// MARK: - Steps

/// Steps of a Side by Side install, in run order.
///
/// Fewer than the Install tab's `Step`: the tunnel goes directly over Wi-Fi (no
/// VPN), and no pairing file is written afterwards since SideInstaller pairs
/// itself.
enum SideBySideStep: Int, CaseIterable, Identifiable {
    case connect, signIn, download, sign, install

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .connect:  return L("Pair with their iPhone")
        case .signIn:   return L("Sign in to their Apple ID")
        case .download: return L("Download SideInstaller")
        case .sign:     return L("Sign the app")
        case .install:  return L("Install on their iPhone")
        }
    }
}

// MARK: - Manager

/// Installs SideInstaller onto *another* iPhone on the same Wi-Fi network.
///
/// Same flow as the Install tab, but over the LAN to a typed-in IP address:
///
/// 1. **Pair.** Run the lockdown `Pair` handshake directly against
///    `<their IP>:62078`. Their iPhone shows a Trust prompt and returns a
///    lockdown pair record, which CoreDeviceProxy (`tunnel_create_usb`) uses to
///    open the tunnel. Works on iOS 17+ without a computer.
/// 2. **Sign in, sign, install** as in the one-click flow, using the credentials
///    entered on this page and the target's UDID.
///
/// Credentials are kept in memory only, never saved to `AccountStore` or the
/// keychain.
final class SideBySideManager: ObservableObject {

    /// Unsigned IPA from SideInstaller's latest GitHub release.
    static let releaseIPA = URL(string:
        "https://github.com/FrizzleM/SideInstaller/releases/latest/download/SideInstaller.ipa")!

    /// What the release asset is called, and what the download is saved as.
    static let ipaFileName = "SideInstaller.ipa"

    // MARK: Inputs

    /// The other iPhone's address on this Wi-Fi network.
    @Published var targetIP = ""
    /// The Apple ID the app is signed with. Never persisted — see the note above.
    @Published var appleID = ""
    @Published var password = ""

    // MARK: State

    @Published private(set) var stepStates: [SideBySideStep: StepState] = Dictionary(
        uniqueKeysWithValues: SideBySideStep.allCases.map { ($0, .pending) })
    @Published private(set) var isRunning = false
    @Published private(set) var finished = false
    /// The far device's name and iOS version, once the link is open.
    @Published private(set) var targetSummary: String?
    /// How much of the download has arrived (0…1), while that step is running.
    @Published private(set) var downloadProgress: Double = 0
    /// Home-screen name of what landed on their iPhone.
    @Published private(set) var installedAppName: String?
    @Published var lastError: String?

    private var task: Task<Void, Never>?

    /// This tool's own link, so a run here never disturbs the Install tab's
    /// connection to the loopback tunnel (or the other way round).
    private let connection = DeviceConnection()
    private let deviceQueue = DispatchQueue(label: "sideinstaller.sidebyside.device")
    private let signQueue = DispatchQueue(label: "sideinstaller.sidebyside.sign")

    private var signSession: OpaquePointer?          // SignSession*
    /// The Apple ID `signSession` belongs to, so editing the field signs out.
    private var signedInAs: String?
    /// Where the pair record for the current target lives.
    private var pairRecordPath: String?
    /// The downloaded IPA, kept between runs so a retry after a signing failure
    /// doesn't fetch it again. Its staging directory is ours to delete.
    private var downloadedIPA: URL?
    private var signedAppPath: String?
    private var targetUDID: String?
    private var targetName: String?
    /// True once the Local Network prompt has been raised, so it asks once.
    private var askedLocalNetwork = false

    private var engine: Engine { Engine.shared }

    deinit {
        if let signSession { si_sign_session_free(signSession) }
        connection.disconnect()
        discardDownload()
    }

    // MARK: - Derived

    /// True when there is enough on the page to start a run.
    var canRun: Bool {
        !Self.tidy(targetIP).isEmpty && !Self.tidy(appleID).isEmpty && !password.isEmpty
    }

    /// This iPhone's Wi-Fi address, shown as an example of what theirs looks like.
    var ownWiFiAddress: String? {
        NetworkStatus.interfaces().first { $0.name == "en0" }?.ipv4
    }

    /// Fraction across all five steps, for the progress bar.
    var overallProgress: Double {
        let total = Double(SideBySideStep.allCases.count)
        let done = Double(SideBySideStep.allCases.filter { stepStates[$0] == .done }.count)
        let partial = stepStates[.download] == .active ? downloadProgress : 0
        return min(1, (done + partial) / total)
    }

    // MARK: - The run

    @MainActor
    func run() {
        guard !isRunning else { return }
        let ip = Self.tidy(targetIP)
        let id = Self.tidy(appleID)
        let pw = password

        guard !ip.isEmpty else {
            lastError = L("Enter the other iPhone's IP address. It's in Settings › Wi-Fi, next to the network it's on.")
            return
        }
        guard Self.isIPv4(ip) else {
            lastError = L("“%@” isn't an IPv4 address. It should look like 192.168.1.42.", ip)
            return
        }
        // Pointed at this iPhone, the whole run would talk to itself.
        guard !NetworkStatus.isOwnAddress(ip) else {
            lastError = L("%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.", ip)
            return
        }
        guard !id.isEmpty, !pw.isEmpty else {
            lastError = L("Enter the Apple ID to sign with, and its password.")
            return
        }
        engine.refreshNetworkStatus()
        guard engine.wifiConnected else {
            lastError = L("Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.")
            return
        }

        // A different Apple ID than the session was opened with invalidates it.
        if let signedInAs, signedInAs.caseInsensitiveCompare(id) != .orderedSame {
            signOut()
        }

        reset()
        isRunning = true
        engine.log("=== Side by Side: installing onto \(ip) ===")

        task = Task { @MainActor in
            do {
                await ensureLocalNetwork()
                try await connectToTarget(ip: ip)
                try await signIn(id: id, pw: pw)
                try await download()
                try await signApp()
                try await install(ip: ip)
                finishSuccess()
            } catch is CancellationError {
                engine.log("Side by Side: cancelled.")
                failActiveStep(to: .pending)
            } catch {
                let message = short(error)
                lastError = message
                engine.log("⛔️ Side by Side stopped: \(message)")
                failActiveStep(to: .failed)
            }
            isRunning = false
        }
    }

    /// Cancels the run at the next step boundary. Blocking FFI calls (e.g.
    /// waiting on the Trust prompt) can't be interrupted, so it takes effect once
    /// the current call returns.
    @MainActor
    func cancel() {
        task?.cancel()
    }

    /// Frees the Apple ID session so the next run signs in again. Called when
    /// the Apple ID changes and by Clear, so another person's session isn't kept.
    ///
    /// Not main-actor isolated: the work runs on `signQueue`, and the session
    /// pointer isn't `Sendable`.
    func signOut() {
        signedInAs = nil
        // Freed on `signQueue`, which owns `signSession`. It's serial, so this
        // can't race the next sign-in.
        signQueue.async { [weak self] in
            guard let self, let session = self.signSession else { return }
            si_sign_session_free(session)
            self.signSession = nil
        }
    }

    /// Disconnects on `deviceQueue`, which owns the connection. Not main-actor
    /// isolated, like `signOut`.
    private func closeLink() {
        deviceQueue.async { [weak self] in self?.connection.disconnect() }
    }

    /// Clear the page back to how it opened, credentials included.
    @MainActor
    func clear() {
        guard !isRunning else { return }
        signOut()
        closeLink()
        discardDownload()
        signedAppPath = nil
        targetUDID = nil
        targetName = nil
        targetSummary = nil
        installedAppName = nil
        appleID = ""
        password = ""
        reset()
    }

    @MainActor
    private func reset() {
        for step in SideBySideStep.allCases { stepStates[step] = .pending }
        downloadProgress = 0
        lastError = nil
        finished = false
    }

    @MainActor
    private func setStep(_ step: SideBySideStep, _ state: StepState) {
        stepStates[step] = state
    }

    @MainActor
    private func failActiveStep(to state: StepState) {
        for step in SideBySideStep.allCases
        where stepStates[step] == .active || stepStates[step] == .waiting {
            stepStates[step] = state
        }
    }

    @MainActor
    private func finishSuccess() {
        finished = true
        let name = installedAppName ?? "SideInstaller"
        engine.log("✅ Side by Side done — \(name) is on \(targetName ?? "their iPhone"). One trust step left, on their side.")
    }

    // MARK: - Step 0: Local Network permission

    /// Triggers the Local Network prompt before the first connect. iOS silently
    /// blocks local-network connections until it's granted.
    @MainActor
    private func ensureLocalNetwork() async {
        guard !askedLocalNetwork else { return }
        askedLocalNetwork = true
        engine.log("Checking Local Network permission — reaching their iPhone needs it…")
        let localNetwork = LocalNetworkAuthorization()
        if await localNetwork.request(timeout: 8) {
            engine.log("Local Network OK.")
        } else {
            engine.log("⚠️ Local Network didn't confirm. If nothing connects, turn it on in Settings › SideInstaller › Local Network.")
        }
    }

    // MARK: - Step 1: pair with the target and open the link

    @MainActor
    private func connectToTarget(ip: String) async throws {
        try Task.checkCancellation()
        setStep(.connect, .waiting)
        let target = try await onDeviceQueue { try self.performConnect(ip: ip) }
        targetSummary = target.summary
        targetUDID = target.udid
        targetName = target.name
        setStep(.connect, .done)
    }

    private struct ConnectedTarget {
        let summary: String
        let udid: String?
        let name: String?
    }

    private func performConnect(ip: String) throws -> ConnectedTarget {
        let record = PrivateStore.peerPairRecord(host: ip)
        pairRecordPath = record.path

        // Try a record saved by an earlier run first: pairing needs a Trust tap
        // and uses one of their device's pairing slots.
        if fileSize(record.path) > 0 {
            do {
                engine.log("Trying the pair record already minted for \(ip) …")
                try connection.connect(deviceIP: ip, pairingFilePath: record.path)
            } catch {
                engine.log("That record didn't open a link (\(error)). Pairing again…")
                try mintPairRecord(ip: ip, into: record)
            }
        } else {
            try mintPairRecord(ip: ip, into: record)
        }

        engine.log("Tunnel + RSD handshake established with \(ip).")
        engine.log(try connection.rsdSummary())

        var values: [String: String] = [:]
        let info = try connection.deviceInfo()
        if info.isEmpty {
            engine.log("Device info: (lockdownd returned no values)")
        } else {
            engine.log("Device info:")
            for (key, value) in info { values[key] = value; engine.log("  \(key) = \(value)") }
        }
        let name = values["DeviceName"] ?? L("device")
        let summary = values["ProductVersion"].map { "\(name) · iOS \($0)" } ?? name
        return ConnectedTarget(summary: summary,
                               udid: values["UniqueDeviceID"],
                               name: values["DeviceName"])
    }

    /// Pairs with the target via lockdown, saves the record, then opens the
    /// tunnel.
    ///
    /// Blocks until the Trust prompt on their iPhone is answered, which is why
    /// the connect step shows as `.waiting`.
    private func mintPairRecord(ip: String, into record: URL) throws {
        engine.log("Asking \(ip) to pair — their iPhone has to be unlocked, and they have to tap Trust …")
        let data = try connection.lockdownPairRecordDirect(
            hosts: [ip],
            hostID: CompositePairingFile.hostID,
            systemBUID: CompositePairingFile.systemBUID,
            hostName: "SideInstaller")
        try data.write(to: record, options: .atomic)
        engine.log("Paired with \(ip) (\(data.count)-byte record). Opening the tunnel over CoreDeviceProxy …")
        try connection.connect(deviceIP: ip, pairingFilePath: record.path)
    }

    // MARK: - Step 2: Apple ID sign-in

    @MainActor
    private func signIn(id: String, pw: String) async throws {
        if signSession != nil, signedInAs?.caseInsensitiveCompare(id) == .orderedSame {
            engine.log("Already signed in as \(Engine.oneLine(id)) — skipping.")
            setStep(.signIn, .done)
            return
        }
        setStep(.signIn, .active)

        // Anisette servers go down often, so try each one before giving up.
        let servers = anisetteCandidates()
        let dir = PrivateStore.isideload.path
        engine.twoFactorWasCancelled = false
        var lastFailure = "no anisette servers configured"
        var appleRefusals = 0

        for (index, anisette) in servers.enumerated() {
            try Task.checkCancellation()
            do {
                let summary = try await onSignQueue {
                    try self.performSignIn(id: id, pw: pw, anisette: anisette, dir: dir)
                }
                engine.anisetteURL = anisette          // stick with what worked
                signedInAs = id
                engine.log("Side by Side: signed in (\(summary)).")
                setStep(.signIn, .done)
                return
            } catch let error as EngineError {
                lastFailure = error.errorDescription ?? "sign-in failed"
                // A cancelled 2FA prompt isn't the server's fault.
                if engine.twoFactorWasCancelled {
                    throw EngineError.message(L("Two-factor verification was cancelled."))
                }
                // Bad credentials fail everywhere, and retrying risks a lockout.
                if Engine.isCredentialError(lastFailure) {
                    engine.log("Apple ID credentials rejected: \(lastFailure)")
                    throw EngineError.message(Engine.credentialErrorMessage)
                }
                engine.log("Side by Side: anisette \(index + 1)/\(servers.count) failed: \(lastFailure)")
                if Engine.isAppleRateLimit(lastFailure) {
                    engine.log("Side by Side: Apple is rate-limiting sign-in (HTTP 429) — stopping.")
                    throw EngineError.message(Engine.appleRateLimitMessage)
                }
                // Apple refusing the request fails the same on every server.
                if Engine.isAppleServiceRefusal(lastFailure) {
                    appleRefusals += 1
                    if appleRefusals >= 2 {
                        engine.log("Side by Side: Apple's sign-in server refused \(appleRefusals) attempts with HTTP 503 — stopping.")
                        throw EngineError.message(Engine.appleServiceRefusalMessage)
                    }
                }
            }
        }
        let tried = servers.count == 1
            ? L("the anisette server")
            : L("all %d anisette servers", servers.count)
        throw EngineError.message(L("Apple ID sign-in failed on %@. Last error: %@", tried, lastFailure))
    }

    /// One sign-in attempt against a specific anisette server. Uses the machine
    /// name `SideInstaller`, so an existing certificate is recognized as reusable.
    private func performSignIn(id: String, pw: String, anisette: String, dir: String) throws -> String {
        defer { engine.endTwoFactor() }
        engine.log("Apple ID sign-in for \(Engine.oneLine(id)) via anisette \(Engine.oneLine(anisette)) …")
        var session: OpaquePointer?
        var summary: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        // 0 = don't save the session: it's someone else's Apple ID.
        let rc = si_apple_signin(id, pw, anisette, "SideInstaller", dir, 0,
                                 sideBySideTwoFactorCallback, nil,
                                 &session, &summary, &error)
        if rc == 0 {
            if let old = signSession { si_sign_session_free(old) }
            signSession = session
            let text = summary.map { String(cString: $0) } ?? ""
            summary.map { si_string_free($0) }
            return text
        } else {
            let message = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message(message)
        }
    }

    // MARK: - Step 3: fetch the release build

    @MainActor
    private func download() async throws {
        try Task.checkCancellation()
        if let existing = downloadedIPA, FileManager.default.fileExists(atPath: existing.path) {
            engine.log("SideInstaller IPA already downloaded — skipping.")
            setStep(.download, .done)
            return
        }
        setStep(.download, .active)
        downloadProgress = 0
        engine.log("Fetching the latest SideInstaller release from \(Self.releaseIPA.absoluteString) …")
        do {
            let file = try await SideStoreDownloader.fetchDirect(
                Self.releaseIPA, named: Self.ipaFileName) { fraction in
                    Task { @MainActor in self.downloadProgress = fraction }
                }
            // Validate now, so an error page or truncated download doesn't fail
            // later during signing.
            guard IPALibrary.looksLikeIPA(file) else {
                try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
                throw EngineError.message(L("The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute."))
            }
            downloadedIPA = file
            downloadProgress = 1
            engine.log("SideInstaller IPA ready at \(file.path) (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize(file.path)), countStyle: .file))).")
            setStep(.download, .done)
        } catch let error as SideStoreDownloader.DownloadError {
            throw EngineError.message(L("Couldn't download the latest SideInstaller release: %@", error.description))
        }
    }

    /// Delete the downloaded IPA and the staging directory it lives in.
    private func discardDownload() {
        guard let file = downloadedIPA else { return }
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
        downloadedIPA = nil
    }

    // MARK: - Step 4: sign for their device

    @MainActor
    private func signApp() async throws {
        try Task.checkCancellation()
        guard let session = signSession else { throw EngineError.message(L("Not signed in.")) }
        guard let ipa = downloadedIPA else { throw EngineError.message(L("No SideInstaller IPA downloaded.")) }
        // Their UDID is registered with the team before the profile is asked
        // for, or Apple refuses it with error 8220.
        let udid = targetUDID ?? ""
        let name = targetName ?? ""
        if udid.isEmpty {
            engine.log("⚠️ No UDID captured from their iPhone — signing may fail with error 8220.")
        }
        setStep(.sign, .active)
        let path = try await onSignQueue {
            try self.performSign(session: session, ipa: ipa.path, udid: udid, deviceName: name)
        }
        signedAppPath = path
        installedAppName = Self.displayName(ofBundleAt: path) ?? "SideInstaller"
        setStep(.sign, .done)
    }

    private func performSign(session: OpaquePointer, ipa: String,
                             udid: String, deviceName: String) throws -> String {
        engine.log("Signing \(ipa) for \(deviceName.isEmpty ? udid : deviceName) …")
        var signed: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_sign_ipa(session, ipa, udid, deviceName, &signed, &error)
        if rc == 0 {
            let path = signed.map { String(cString: $0) } ?? ""
            signed.map { si_string_free($0) }
            engine.log("Signed bundle at \(path)")
            return path
        } else {
            let message = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            engine.log("Sign FAILED: \(message)")
            // Same errors as the Install tab, worded for another person's
            // account and iPhone.
            if Engine.isCertExistsError(message) {
                throw EngineError.message(L("Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise."))
            }
            if Engine.isDeviceRegistrationError(message) {
                throw EngineError.message(L("Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@", message))
            }
            throw EngineError.message(L("Signing failed: %@", message))
        }
    }

    /// Home-screen name read from the signed `.app` (display name, else bundle
    /// name).
    private static func displayName(ofBundleAt path: String) -> String? {
        let plist = (path as NSString).appendingPathComponent("Info.plist")
        guard let data = FileManager.default.contents(atPath: plist),
              let parsed = try? PropertyListSerialization.propertyList(from: data,
                                                                       options: [],
                                                                       format: nil),
              let dict = parsed as? [String: Any]
        else { return nil }
        let name = (dict["CFBundleDisplayName"] as? String) ?? (dict["CFBundleName"] as? String)
        return (name?.isEmpty == false) ? name : nil
    }

    // MARK: - Step 5: install over AFC + installation_proxy

    @MainActor
    private func install(ip: String) async throws {
        try Task.checkCancellation()
        guard let bundle = signedAppPath else { throw EngineError.message(L("No signed bundle to install.")) }
        guard let record = pairRecordPath else { throw EngineError.message(L("No pair record for their iPhone.")) }
        setStep(.install, .active)
        engine.installProgress = 0
        try await onDeviceQueue {
            // iOS drops the idle tunnel during sign-in and signing, and
            // `isConnected` doesn't detect it, so reconnect first.
            self.engine.log("Refreshing the link to \(ip) before installing …")
            try self.connection.connect(deviceIP: ip, pairingFilePath: record)
            guard self.connection.isConnected else {
                throw EngineError.message(L("The link to their iPhone dropped — start again."))
            }
            self.engine.log("Installing the signed bundle via AFC + installation_proxy …")
            try self.connection.installSignedApp(bundlePath: bundle)
            self.engine.log("Install request completed.")
        }
        engine.installProgress = 1
        setStep(.install, .done)
    }

    // MARK: - Helpers

    /// Anisette addresses to try, the engine's current pick first.
    private func anisetteCandidates() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for address in [engine.anisetteURL] + engine.anisetteServers.map(\.address) {
            let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, seen.insert(trimmed).inserted { out.append(trimmed) }
        }
        return out
    }

    private static func tidy(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True for a dotted-quad IPv4 address. Checked early for a clear error.
    private static func isIPv4(_ value: String) -> Bool {
        let octets = value.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }
        return octets.allSatisfy { UInt8($0) != nil }
    }

    private func fileSize(_ path: String) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int) ?? 0
    }

    private func short(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    /// Bridge a blocking device call to async, serialized on this tool's queue.
    private func onDeviceQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            deviceQueue.async {
                do { cont.resume(returning: try work()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    /// The same, on the signing queue: isideload's session isn't thread-safe.
    private func onSignQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            signQueue.async {
                do { cont.resume(returning: try work()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}

// MARK: - C 2FA callback

/// Bridges a 2FA request during a Side by Side sign-in to the engine's shared
/// prompt, which `RootView` presents over whichever tab is showing.
private let sideBySideTwoFactorCallback: SITwoFactorCb = { _, request, outBuf, bufLen in
    Engine.shared.answerTwoFactor(request: request, outBuf: outBuf, len: Int(bufLen))
}

// MARK: - View

/// Installs SideInstaller onto somebody else's iPhone across the Wi-Fi network.
/// Pushed from Tools, whose `NavigationStack` this relies on.
struct SideBySideView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// Read for the install step's progress, which installd reports globally.
    @EnvironmentObject private var engine: Engine
    /// Observed so the "use my saved Apple ID" button follows the saved account.
    @EnvironmentObject private var accounts: AccountStore
    @ObservedObject var manager: SideBySideManager

    @State private var showSettings = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case address, email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header.cascadeItem(0)
                targetCard.cascadeItem(1)
                accountCard.cascadeItem(2)
                stepsCard.cascadeItem(3)
                actionButton.cascadeItem(4)
                if let error = manager.lastError {
                    errorCallout(error).transition(.cardAppear)
                }
                if manager.finished {
                    successCallout.transition(.cardAppear)
                }
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: manager.lastError)
            .animation(.smooth(duration: 0.35), value: manager.targetSummary)
            .animation(.smooth(duration: 0.3), value: manager.isRunning)
            .animation(.smooth(duration: 0.4, extraBounce: 0.12), value: manager.finished)
        }
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "iphone.gen3.radiowaves.left.and.right",
                    image: "SideBySideLogo",
                    title: L("Side by Side"),
                    beta: true,
                    subtitle: L("Set up someone else's iPhone"),
                    animateIcon: manager.isRunning) {
            if let summary = manager.targetSummary {
                StatusPill(text: summary, systemImage: "iphone", color: .green)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
            } else {
                StatusPill(text: L("Same Wi-Fi network"), systemImage: "wifi", color: .secondary, glass: true)
            }
        }
    }

    // MARK: Their iPhone

    private var targetCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L("Their iPhone"), systemImage: "iphone")
                // Their iPhone needs iOS 27+ so the installed app can pair itself.
                // This can't be checked before the run.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(L("Their iPhone needs iOS %@ — SideInstaller pairs itself once it's installed, and nothing older can.",
                           Engine.minimumOSText))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                TextField(L("IP address (e.g. 192.168.1.42)"), text: $manager.targetIP)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused($focus, equals: .address)
                    .disabled(manager.isRunning)
                    .fieldBackground()
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// How to find their IP, plus this iPhone's address as an example.
    private var hint: String {
        let route = L("On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.")
        guard let own = manager.ownWiFiAddress else { return route }
        return route + " " + L("This iPhone is %@, so theirs will look similar.", own)
    }

    // MARK: The Apple ID

    private var accountCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L("Apple ID to sign with"), systemImage: "person.crop.circle")
                TextField(L("Email"), text: $manager.appleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    // No `.username`/`.password` content types on this card:
                    // these are someone else's credentials, so don't offer to
                    // save them to the keychain.
                    .textFieldStyle(.plain)
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
                    .disabled(manager.isRunning)
                    .fieldBackground()
                SecureField(L("Password"), text: $manager.password)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .focused($focus, equals: .password)
                    .disabled(manager.isRunning)
                    .fieldBackground()
                Text(L("Tip: Use the iPhone/iPad owner's Apple account credentials"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if accounts.active != nil, !manager.isRunning {
                    Button(L("Use my saved Apple ID instead")) {
                        manager.appleID = accounts.activeAppleID
                        manager.password = accounts.activePassword
                        focus = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: Steps

    private var stepsCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(L("Steps"), systemImage: "list.bullet")
                ForEach(SideBySideStep.allCases) { step in
                    SideBySideStepRow(title: step.title,
                                      state: manager.stepStates[step] ?? .pending,
                                      detail: detail(for: step))
                }
                if manager.isRunning || manager.finished {
                    ProgressView(value: manager.overallProgress)
                        .tint(Theme.accent)
                }
            }
        }
    }

    /// The extra line a step carries while it is the one in flight.
    private func detail(for step: SideBySideStep) -> String? {
        let state = manager.stepStates[step] ?? .pending
        guard state == .active || state == .waiting else { return nil }
        switch step {
        case .connect:
            return L("Waiting for them to tap Trust…")
        case .download:
            return L("%d%% downloaded", Int(manager.downloadProgress * 100))
        case .install:
            return L("%d%% uploaded", Int(engine.installProgress * 100))
        default:
            return nil
        }
    }

    // MARK: Action

    @ViewBuilder
    private var actionButton: some View {
        if manager.isRunning {
            Button(role: .cancel) {
                manager.cancel()
            } label: {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(L("Cancel"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(gradient: Theme.gradient(.red), glow: .red))
        } else {
            VStack(spacing: 12) {
                Button {
                    focus = nil
                    manager.run()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "iphone.and.arrow.forward")
                        Text(manager.finished ? L("Install again") : L("Start the install"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!manager.canRun)
                .opacity(manager.canRun ? 1 : 0.35)
                .animation(.snappy(duration: 0.25), value: manager.canRun)

                if manager.finished || !manager.appleID.isEmpty {
                    Button(L("Clear their details")) { manager.clear() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Callouts

    private var successCallout: some View {
        CalloutCard(tint: .green) {
            VStack(alignment: .leading, spacing: 10) {
                Label(L("Last step: they trust %@", manager.installedAppName ?? "SideInstaller"),
                      systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("On their iPhone: Settings › General › VPN & Device Management."))
                    Text(L("Tap the Apple ID under “Developer App”, then tap Trust."))
                    Text(L("Open it from their Home Screen — they're set up."))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func errorCallout(_ message: String) -> some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Something went wrong"))
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.brand)
        }
    }
}

// MARK: - Step row

/// One row of the Side by Side checklist: a status node, the title, and the
/// line the step adds while it is the one in flight.
private struct SideBySideStepRow: View {
    let title: String
    let state: StepState
    var detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            node
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(state == .pending ? .regular : .medium))
                    .foregroundStyle(state == .pending ? .secondary : .primary)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .animation(.smooth(duration: 0.3), value: state)
    }

    @ViewBuilder
    private var node: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.red)
        case .active:
            ProgressView().controlSize(.small)
        case .waiting:
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 15))
                .foregroundStyle(.orange)
        case .pending:
            Circle()
                .strokeBorder(Color(.tertiaryLabel), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
    }
}
