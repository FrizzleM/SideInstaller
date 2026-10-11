import ActivityKit
import UIKit

/// Drives the pairing Live Activity (`PairingActivityAttributes`) for
/// `PairingController`: up when this iPhone starts pairing, showing the code
/// once Settings asks for it, and down again when pairing ends.
///
/// The app is behind Settings for most of that, kept running by pairing's
/// keep-alive audio, which is what lets it update the activity from there.
@MainActor
final class PairingLiveActivity: PairingCodeSurface {

    static let shared = PairingLiveActivity()

    private typealias PairingActivity = Activity<PairingActivityAttributes>
    private typealias ContentState = PairingActivityAttributes.ContentState

    /// True when the widget extension that draws the activity is in the app.
    /// A build signed with a certificate that only covers the app's own
    /// identifier ships without it (see `scripts/sign_with_all_certs.sh`), and
    /// an activity started then would be an empty box. `PairingNotification`
    /// stands in there.
    nonisolated static let hasExtension: Bool = {
        guard let plugIns = Bundle.main.builtInPlugInsURL,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: plugIns, includingPropertiesForKeys: nil) else { return false }
        return contents.contains { $0.pathExtension == "appex" }
    }()

    /// True when a pairing run will show its code over Settings: the extension
    /// is there, and Live Activities are on for SideInstaller.
    nonisolated static var isAvailable: Bool {
        hasExtension && ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// How long "Paired" stays up when nobody comes back to the app.
    private static let pairedHold: Duration = .seconds(15)

    private var activity: PairingActivity?
    /// The last operation queued. Each waits for the one before it, so the
    /// system gets the updates in the order pairing made them.
    private var queue: Task<Void, Never>?
    /// The wait that keeps "Paired" up; cancelled to take it down early.
    private var hold: Task<Void, Never>?

    private init() {
        // Back in the app, "Paired" has nothing left to say.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hold?.cancel() }
        }
    }

    // MARK: Pairing's milestones

    /// Pairing has begun: put up where to go in Settings. Call it with the app
    /// in front, which starting an activity needs.
    func start() {
        guard Self.isAvailable else { return }
        enqueue { [self] in
            await endAll()
            do {
                activity = try PairingActivity.request(
                    attributes: PairingActivityAttributes(), content: Self.content(.waiting))
            } catch {
                // The popup in the app still shows the code.
                Engine.shared.log("Live Activity: not started — \(error.localizedDescription)")
            }
        }
    }

    /// Settings is asking for `code`. The alert opens the Dynamic Island on it,
    /// or drops it down as a banner on an iPhone without one.
    func show(code: String) {
        enqueue { [self] in
            let content = Self.content(.code(code))
            await activity?.update(content, alertConfiguration: Self.alert(for: content))
        }
    }

    /// Pairing ended. A success says so until the app is back in front, since
    /// the install only goes on from there; anything else just takes the
    /// activity down, and the app explains.
    func finish(paired: Bool) {
        enqueue { [self] in
            guard let activity else { return }
            self.activity = nil

            let app = UIApplication.shared
            if paired, app.applicationState != .active {
                let wait = Task { _ = try? await Task.sleep(for: Self.pairedHold) }
                hold = wait
                // Pairing's keep-alive audio has stopped, so this is what
                // keeps the app running long enough to take the activity down.
                let background = app.beginBackgroundTask { wait.cancel() }
                let content = Self.content(.paired)
                await activity.update(content, alertConfiguration: Self.alert(for: content))
                await wait.value
                hold = nil
                await activity.end(nil, dismissalPolicy: .immediate)
                app.endBackgroundTask(background)
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Takes down an activity left up by a run that was killed before it could.
    func endLeftovers() {
        guard Self.hasExtension else { return }
        enqueue { [self] in await endAll() }
    }

    // MARK: Helpers

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            await operation()
        }
    }

    private func endAll() async {
        activity = nil
        for leftover in PairingActivity.activities {
            await leftover.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func content(_ stage: ContentState.Stage) -> ActivityContent<ContentState> {
        let title: String
        let detail: String
        switch stage {
        case .waiting:
            title = L("Pair in Settings")
            detail = L("Privacy & Security › Developer Mode › Pair with SideInstaller")
        case .code:
            title = L("Pairing code")
            detail = L("Type this into the prompt in Settings.")
        case .paired:
            title = L("Paired")
            detail = L("Tap to return to SideInstaller.")
        }
        return ActivityContent(state: ContentState(stage: stage, title: title, detail: detail),
                               staleDate: nil)
    }

    /// The alert for an update. Its text only shows on a paired Apple Watch; on
    /// the iPhone it's what expands the activity.
    private static func alert(for content: ActivityContent<ContentState>) -> AlertConfiguration {
        AlertConfiguration(
            title: LocalizedStringResource(String.LocalizationValue(content.state.title)),
            body: LocalizedStringResource(String.LocalizationValue(content.state.detail)),
            sound: .default)
    }
}
