import SwiftUI

@main
struct SideInstallerApp: App {
    // The one engine, handed to every screen through the environment.
    @State private var engine = Engine.shared
    // Checks GitHub for a newer release and drives the update banner.
    @StateObject private var updateChecker = UpdateChecker()
    // Held here so every screen redraws when the language setting changes.
    @StateObject private var localizer = Localizer.shared
    // The saved Apple IDs, shared by every screen that signs in.
    @StateObject private var accounts = AccountStore.shared
    /// False until the TOS is accepted on the first setup page.
    @AppStorage(SetupView.acceptedTermsKey) private var hasAcceptedTOS = false
    /// False until account setup is completed or skipped. Never reset, even if
    /// all accounts are removed later.
    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false

    init() {
        // A pairing code still up from a run that was killed means nothing now.
        PairingLiveActivity.shared.endLeftovers()
        PairingNotification.shared.reset()
        // So is an install's progress.
        InstallActivity.shared.endLeftovers()
        // iOS hands over the last crash's diagnostic now, for Report a problem.
        CrashDiagnostics.shared.start()
        // Drawn now so the first tap already has its sound.
        SoundEffects.prepare()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasAcceptedTOS && hasCompletedAccountSetup {
                    RootView()
                        .environment(engine)
                        .environmentObject(updateChecker)
                        .environmentObject(localizer)
                        .environmentObject(accounts)
                        .task { await updateChecker.check() }
                        .transition(.opacity)
                } else {
                    // The terms, the sideinstaller.net question and the Apple
                    // ID, a page each; the pages move among themselves.
                    SetupView()
                        .environmentObject(localizer)
                        .environmentObject(accounts)
                        // Zoom past the camera while the app fades in beneath.
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 1.06))))
                        .zIndex(1)
                }
            }
            .animation(.smooth(duration: 0.5), value: hasCompletedAccountSetup)
            // Every switch in the app clicks on and off.
            .toggleStyle(SoundingToggleStyle())
            // Files opened in the app (share sheet, "Open with", other apps), as
            // an alternative to the document picker, and `sideinstaller://`
            // links, which ask before doing anything.
            .onOpenURL { url in
                guard url.isFileURL else {
                    engine.receiveLink(url)
                    return
                }
                // `.mobiledevicepairing`/`.plist` are pairing files; anything else
                // is treated as an IPA.
                if ["mobiledevicepairing", "plist"].contains(url.pathExtension.lowercased()) {
                    Task { await engine.importPairingFile(from: url) }
                } else {
                    engine.installSource = .custom
                    Task { await engine.importCustomIPA(from: url) }
                }
            }
        }
    }
}
