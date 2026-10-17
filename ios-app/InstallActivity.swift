import ActivityKit
import BackgroundTasks
import Combine
import UIKit

/// Shows a one-click install's progress outside the app, says so when the run
/// needs the user or has stopped, and keeps the install going there.
///
/// On iOS 26 and later the run is a `BGContinuedProcessingTask`: iOS keeps the
/// app running in the background for it and shows its progress in a Live
/// Activity of its own, which can also stop it. Below 26, or when iOS turns the
/// task down, SideInstaller's own Live Activity (`InstallActivityAttributes`)
/// shows the progress instead, and the run has the half minute or so of
/// background time any app gets. When that's up, the activity says so, and the
/// install goes on once SideInstaller is open again.
///
/// When the run needs the user (a 2FA code, the App IDs a custom IPA costs, the
/// tunnel, Wi-Fi, a Trust prompt) or stops on an error, SideInstaller's activity
/// turns to that, and alerts, which opens the Dynamic Island on it. On iOS 26
/// and later the background task's own UI can only take a title and a subtitle,
/// so they say it there; and since iOS lets an app start a Live Activity only
/// until it has left the foreground, SideInstaller's goes up next to the task's
/// when the user leaves the app while the run needs them, and comes down once
/// it doesn't.
///
/// Neither starts while this iPhone still has to pair: the pairing Live
/// Activity has the Dynamic Island then, and `KeepAlive` keeps the app running.
/// They go up once the app is in front past that, which on a fresh pairing is
/// when the user comes back from Settings.
@MainActor
final class InstallActivity {

    static let shared = InstallActivity()

    /// How a run ended.
    enum Outcome { case installed, stopped, cancelled }

    private typealias State = InstallActivityAttributes.ContentState
    private typealias LiveActivity = Activity<InstallActivityAttributes>

    /// How long a background task that stopped on an error keeps saying so in
    /// its UI, for the user to come back to; iOS takes the UI down with the task.
    private static let stoppedHold: Duration = .seconds(180)

    private var running = false
    /// The build and its name, fixed when the run starts.
    private var source: InstallSource = .sideStore
    private var buildName = ""
    /// True once the run has tried for a surface; at most one try per run.
    private var surfaced = false
    /// True while the run sits suspended in the background, below iOS 26.
    private var paused = false
    private var observers: Set<AnyCancellable> = []

    /// The identifier of the background task this run submitted, until it ends.
    private var taskID: String?
    /// That task, once iOS has started it. Always a `BGContinuedProcessingTask`.
    private var task: BGTask?
    /// What the task's UI shows now.
    private var taskShows: State?
    /// How the run ended, when it ended before iOS started its task.
    private var endedBeforeTask: Outcome?
    /// The wait that keeps a task that stopped on an error up, cancelled when
    /// the user is back.
    private var stoppedTaskHold: Task<Void, Never>?

    /// SideInstaller's own Live Activity.
    private var activity: LiveActivity?
    /// True when it's up only while the run needs the user, next to the
    /// background task's, which shows the progress.
    private var activityOnlyForNeeds = false
    /// What it shows now.
    private var activityShows: State?
    /// The last activity operation queued. Each waits for the one before it,
    /// so the system gets the updates in the order the run made them.
    private var queue: Task<Void, Never>?

    /// UIKit's background time, held for the whole run: the half minute the
    /// install gets without a background task, and time to wind down after one.
    private var grace: UIBackgroundTaskIdentifier = .invalid
    /// Every grant not handed back yet, `grace` and any a run ending let go of.
    private var held: Set<UIBackgroundTaskIdentifier> = []

    private init() {
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.cameToForeground() }
        }
        // Both, since iOS lets an app start a Live Activity until it has left
        // the foreground, and a resign alone may be a pulled-down Control Center.
        for name in [UIApplication.willResignActiveNotification,
                     UIApplication.didEnterBackgroundNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.leavingForeground() }
            }
        }
    }

    // MARK: The run

    /// A run started. Call it with the app in front, right after the tap.
    func runStarted() {
        let engine = Engine.shared
        releaseStoppedTask()
        endActivity()
        running = true
        surfaced = false
        paused = false
        endedBeforeTask = nil
        source = engine.installSource
        buildName = source == .custom
            ? engine.customIPAName.map { ($0 as NSString).deletingPathExtension } ?? source.displayName
            : source.displayName

        // `@Published` sends before it stores, so read the engine a turn later.
        let changes: [AnyPublisher<Void, Never>] = [
            engine.$stepStates.map { _ in () }.eraseToAnyPublisher(),
            engine.$installProgress.map { _ in () }.eraseToAnyPublisher(),
            engine.$isCancelling.map { _ in () }.eraseToAnyPublisher(),
            engine.$twoFactor.map { _ in () }.eraseToAnyPublisher(),
            engine.$appIDCost.map { _ in () }.eraseToAnyPublisher(),
            engine.$guide.map { _ in () }.eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: AttentionGate.didChange)
                .map { _ in () }.eraseToAnyPublisher(),
        ]
        observers = [
            Publishers.MergeMany(changes)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.refresh() },
        ]
        beginGrace()
        surfaceIfReady()
    }

    /// The run ended. Away from the app, the surfaces say how until the user is
    /// back: an error stays up in the Dynamic Island, a finished install on the
    /// Lock Screen. In front, they come down, and the app says the rest.
    func runEnded(_ outcome: Outcome) {
        guard running else { return }
        running = false
        observers = []
        paused = false
        let away = UIApplication.shared.applicationState != .active
        let last: State? = switch outcome {
        case .installed: installedState()
        case .stopped:   stoppedState()
        case .cancelled: nil
        }

        if #available(iOS 26.0, *), let task = task as? BGContinuedProcessingTask {
            if away, outcome == .stopped, let last {
                holdStopped(task, last)
            } else {
                complete(task, outcome)
            }
        } else if taskID != nil {
            // Submitted but not started: it ends as soon as iOS starts it.
            endedBeforeTask = outcome
        }

        if let activity, away, let last, outcome == .stopped || !activityOnlyForNeeds {
            activityShows = last
            enqueue {
                await activity.update(Self.content(last), alertConfiguration: Self.alert(for: last))
                // An error stays up, in the Dynamic Island too, until the user is
                // back; a finished install only on the Lock Screen.
                if outcome == .installed {
                    await activity.end(Self.content(last), dismissalPolicy: .default)
                }
            }
            if outcome == .installed { self.activity = nil }
        } else {
            endActivity()
        }
        taskShows = nil
        // After the surfaces' last word, which needs the app running to send.
        let ending = grace
        grace = .invalid
        enqueue { [self] in handBack(ending) }
    }

    /// Takes down an activity left up by a run that was killed before it could.
    func endLeftovers() {
        guard PairingLiveActivity.hasExtension else { return }
        enqueue { [self] in await endAllActivities() }
    }

    // MARK: Following the run

    private func refresh() {
        guard running else { return }
        surfaceIfReady()
        show(currentState())
    }

    private func cameToForeground() {
        guard running else {
            // The app says the rest about a run that ended while it was away.
            releaseStoppedTask()
            activity = nil
            activityShows = nil
            enqueue { [self] in await endAllActivities() }
            return
        }
        beginGrace()
        if paused {
            paused = false
            Engine.shared.log("Back in SideInstaller — the install carries on.")
        }
        // In front, the app's popups say what the run needs.
        if activityOnlyForNeeds { endActivity() }
        surfaceIfReady()
        show(currentState())
    }

    /// The last moment iOS lets the app start a Live Activity. When the run
    /// needs the user and the background task has the progress, SideInstaller's
    /// own goes up for the need.
    private func leavingForeground() {
        guard running, task != nil, activity == nil else { return }
        let state = currentState()
        guard state.needsUser else { return }
        startActivity(state, onlyForNeeds: true)
    }

    private func currentState() -> State {
        let engine = Engine.shared
        let progress = engine.overallProgress
        if paused {
            return State(stage: .paused, title: L("Paused"),
                         detail: L("Open SideInstaller to finish the install."),
                         symbol: "pause.fill", progress: progress)
        }
        if let need = currentNeed() {
            return State(stage: .waiting, title: need.title, detail: need.detail,
                         action: L("Tap to return to SideInstaller."), symbol: need.symbol,
                         progress: progress)
        }
        // Between two steps, the next one.
        let step = Step.allCases.first { engine.stepStates[$0] == .waiting }
            ?? Step.allCases.first { engine.stepStates[$0] == .active }
            ?? Step.allCases.first { engine.stepStates[$0] != .done }
        return State(stage: .running,
                     title: engine.isCancelling ? L("Cancelling") : L("Installing %@", buildName),
                     detail: step?.title(for: source) ?? "", progress: progress)
    }

    /// What the run is waiting for the user to do, if anything. Pairing isn't
    /// one: its own Live Activity has that.
    private func currentNeed() -> (title: String, detail: String, symbol: String)? {
        let engine = Engine.shared
        if case .asking(let prompt) = engine.twoFactor {
            // Without the number Apple masks: this shows on the Lock Screen.
            let detail = switch prompt.method {
            case .device: L("Enter the code Apple just sent to your trusted device.")
            case .sms:    L("Enter the code Apple texted to your phone.")
            case .voice:  L("Apple is calling your phone. Enter the code you hear.")
            case .choose: L("Choose how Apple should send your verification code.")
            }
            return (prompt.expectsCode ? L("Two-Factor Code") : L("Choose How to Get a Code"),
                    detail, "key.fill")
        }
        if let cost = engine.appIDCost {
            let detail = cost.isAffordable
                ? L("Check the App IDs it needs, then tap Install.")
                : L("This Apple ID doesn't have enough App IDs left: this app needs %d, and %d are left. Each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.",
                    cost.cost, cost.available ?? 0)
            return (L("App IDs for this app"), detail, "number.square.fill")
        }
        if engine.attention.isHeld {
            return (L("Tap Trust"), L("Unlock this iPhone and tap Trust when it asks."), "hand.tap.fill")
        }
        if engine.stepStates[.network] == .waiting, let guide = engine.guide {
            return (guide.title, guide.steps.first ?? "", guide.systemImage)
        }
        return nil
    }

    private func installedState() -> State {
        State(stage: .installed, title: L("Installed"),
              detail: L("Tap to return to SideInstaller."), symbol: "checkmark", progress: 1)
    }

    private func stoppedState() -> State {
        let engine = Engine.shared
        return State(stage: .stopped, title: L("Install stopped"),
                     detail: engine.lastError ?? "", action: L("Tap to return to SideInstaller."),
                     symbol: "exclamationmark.triangle.fill", progress: engine.overallProgress)
    }

    /// Puts up a surface once the app is in front and done pairing.
    private func surfaceIfReady() {
        guard running, !surfaced, UIApplication.shared.applicationState == .active else { return }
        let pairing = Engine.shared.stepStates[.pair]
        guard pairing != .waiting, pairing == .done || !Engine.shared.needsFreshPairing else { return }
        surfaced = true
        if #available(iOS 26.0, *), submitTask() { return }
        startActivity(currentState(), onlyForNeeds: false)
    }

    private func show(_ state: State) {
        if #available(iOS 26.0, *), let task = task as? BGContinuedProcessingTask,
           Self.differs(state, from: taskShows) {
            taskShows = state
            if task.title != state.title || task.subtitle != state.detail {
                task.updateTitle(state.title, subtitle: state.detail)
            }
            task.progress.completedUnitCount = Int64(state.progress * Double(task.progress.totalUnitCount))
        }

        guard let activity else { return }
        if activityOnlyForNeeds, !state.needsUser {
            // Done with: the task's UI has the progress again.
            endActivity()
            return
        }
        guard Self.differs(state, from: activityShows) else { return }
        // A new need opens the Dynamic Island on it, unless the app is in
        // front, where its popup already says so.
        let isNew = activityShows.map { !$0.needsUser || $0.stage != state.stage || $0.title != state.title } ?? true
        let alert = state.needsUser && isNew && UIApplication.shared.applicationState != .active
        activityShows = state
        enqueue {
            await activity.update(Self.content(state), alertConfiguration: alert ? Self.alert(for: state) : nil)
        }
    }

    /// True when showing `state` instead of `other` changes what's on screen.
    private static func differs(_ state: State, from other: State?) -> Bool {
        guard var other else { return true }
        var state = state
        state.progress = (state.progress * 100).rounded(.down)
        other.progress = (other.progress * 100).rounded(.down)
        return state != other
    }

    // MARK: Background time

    private func beginGrace() {
        guard grace == .invalid else { return }
        var id = UIBackgroundTaskIdentifier.invalid
        id = UIApplication.shared.beginBackgroundTask(withName: "Install") { [weak self] in
            MainActor.assumeIsolated { self?.graceRanOut(id) }
        }
        guard id != .invalid else { return }
        grace = id
        held.insert(id)
    }

    private func handBack(_ id: UIBackgroundTaskIdentifier) {
        guard held.remove(id) != nil else { return }
        UIApplication.shared.endBackgroundTask(id)
    }

    /// The half minute is up. With a background task the app keeps running;
    /// without one it's about to be suspended, and the activity says so first.
    private func graceRanOut(_ id: UIBackgroundTaskIdentifier) {
        let current = id == grace
        if current { grace = .invalid }
        guard current, running, task == nil else {
            handBack(id)
            return
        }
        paused = true
        Engine.shared.log("Out of background time — the install goes on once SideInstaller is open again.")
        show(currentState())
        // Handed back once the activity has it, but within a second whatever
        // is still queued: iOS ends an app that keeps the time past its end.
        enqueue { [self] in handBack(id) }
        Task {
            try? await Task.sleep(for: .seconds(1))
            handBack(id)
        }
    }

    // MARK: iOS 26 and later: a continued-processing task

    /// The identifiers Info.plist lets the app submit.
    private static let permittedTaskIDs: [String] =
        Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []

    /// Submits the run as a background task; false when it can't be. iOS may
    /// still turn it down afterwards (`taskRefused`).
    @available(iOS 26.0, *)
    private func submitTask() -> Bool {
        let engine = Engine.shared
        // iOS takes only identifiers under the app's own bundle ID, and those
        // Info.plist allows. A build signed under another bundle ID has the
        // original one in its Info.plist, and gets the Live Activity.
        guard let bundleID = Bundle.main.bundleIdentifier,
              Self.permittedTaskIDs.contains("\(bundleID).install.*") else {
            engine.log("Background task: Info.plist doesn't allow one under this bundle ID — showing a Live Activity instead.")
            return false
        }
        // Registering an identifier twice ends the app, so each run has its own.
        let identifier = "\(bundleID).install.\(UUID().uuidString)"
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier,
                                                         using: .main) { [weak self] task in
            task.expirationHandler = { [weak self] in
                Task { @MainActor in self?.taskExpired(task) }
            }
            MainActor.assumeIsolated { self?.taskStarted(task) }
        }
        guard registered else {
            engine.log("Background task: iOS wouldn't register \(identifier) — showing a Live Activity instead.")
            return false
        }

        let state = currentState()
        let request = BGContinuedProcessingTaskRequest(identifier: identifier,
                                                       title: state.title, subtitle: state.detail)
        // A task iOS only queues would start after the user stopped waiting.
        request.strategy = .fail
        taskID = identifier
        if #available(iOS 27.0, *) {
            // Not from the main thread, the header says.
            Task.detached { [weak self] in
                do {
                    try await BGTaskScheduler.shared.submitTaskRequest(request)
                } catch {
                    await self?.taskRefused(identifier, error)
                }
            }
        } else {
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                taskRefused(identifier, error)
            }
        }
        return true
    }

    private func taskRefused(_ identifier: String, _ error: Error) {
        guard taskID == identifier else { return }
        taskID = nil
        let ns = error as NSError
        Engine.shared.log("Background task: iOS turned it down (\(ns.domain) \(ns.code)) — showing a Live Activity instead.")
        if running, activity == nil { startActivity(currentState(), onlyForNeeds: false) }
    }

    @available(iOS 26.0, *)
    private func taskStarted(_ started: BGTask) {
        guard let task = started as? BGContinuedProcessingTask, task.identifier == taskID else {
            started.setTaskCompleted(success: false)
            return
        }
        guard running else {
            // The run ended before iOS got to it.
            complete(task, endedBeforeTask ?? .cancelled)
            return
        }
        self.task = task
        task.progress.totalUnitCount = 1000
        taskShows = nil
        show(currentState())
        Engine.shared.log("Background task: running — the install carries on if you leave SideInstaller.")
    }

    /// iOS took the task back: the user stopped it from its Live Activity, or
    /// the system needed the resources.
    private func taskExpired(_ expired: BGTask) {
        guard expired === task else { return }
        task = nil
        taskID = nil
        stoppedTaskHold?.cancel()
        stoppedTaskHold = nil
        expired.setTaskCompleted(success: false)
        guard running else { return }
        if UIApplication.shared.applicationState == .active {
            // In front, the run doesn't need it.
            Engine.shared.log("Background task: iOS ended it — the install carries on while SideInstaller is open.")
        } else {
            // There's no telling the two apart, and either way the run can't go
            // on in the background.
            Engine.shared.log("Background task: stopped from its Live Activity, or iOS took it back — cancelling the install.")
            beginGrace()
            Engine.shared.cancelOneClick()
        }
    }

    /// Keeps a task the run stopped on up, saying why, until the user is back
    /// or `stoppedHold` is up: completing it takes its UI down.
    @available(iOS 26.0, *)
    private func holdStopped(_ task: BGContinuedProcessingTask, _ state: State) {
        task.updateTitle(state.title, subtitle: state.detail)
        Engine.shared.log("Background task: the install stopped — saying so until you're back in SideInstaller.")
        stoppedTaskHold = Task { [weak self] in
            try? await Task.sleep(for: Self.stoppedHold)
            guard !Task.isCancelled else { return }
            self?.releaseStoppedTask()
        }
    }

    private func releaseStoppedTask() {
        stoppedTaskHold?.cancel()
        stoppedTaskHold = nil
        guard !running, let task else { return }
        if #available(iOS 26.0, *), let task = task as? BGContinuedProcessingTask {
            complete(task, .stopped)
        }
    }

    @available(iOS 26.0, *)
    private func complete(_ task: BGContinuedProcessingTask, _ outcome: Outcome) {
        switch outcome {
        case .installed:
            let last = installedState()
            task.updateTitle(last.title, subtitle: buildName)
            task.progress.completedUnitCount = task.progress.totalUnitCount
        case .stopped:
            let last = stoppedState()
            if task.title != last.title { task.updateTitle(last.title, subtitle: last.detail) }
        case .cancelled:
            break
        }
        task.setTaskCompleted(success: outcome == .installed)
        if self.task === task { self.task = nil }
        if taskID == task.identifier { taskID = nil }
    }

    // MARK: SideInstaller's own Live Activity

    /// Starts SideInstaller's activity on `state`: for the whole run when it
    /// stands in for the background task, or only while the run needs the user.
    /// The app has to be in front, or just leaving it.
    private func startActivity(_ state: State, onlyForNeeds: Bool) {
        let engine = Engine.shared
        guard PairingLiveActivity.hasExtension else {
            if !onlyForNeeds {
                engine.log("Install Live Activity: not in this build — the install runs while SideInstaller is open.")
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            if !onlyForNeeds {
                engine.log("Install Live Activity: not started — Live Activities are off for SideInstaller in Settings.")
            }
            return
        }
        let leftovers = LiveActivity.activities
        do {
            // Not queued: iOS stops taking requests moments after the app leaves
            // the foreground.
            activity = try LiveActivity.request(attributes: InstallActivityAttributes(),
                                                content: Self.content(state))
            activityOnlyForNeeds = onlyForNeeds
            activityShows = state
            engine.log(onlyForNeeds ? "Install Live Activity: up while the install needs you."
                                    : "Install Live Activity: started.")
        } catch {
            engine.log("Install Live Activity: not started — \(error.localizedDescription)")
        }
        for leftover in leftovers {
            enqueue { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        activityShows = nil
        activityOnlyForNeeds = false
        enqueue { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            await operation()
        }
    }

    private func endAllActivities() async {
        for leftover in LiveActivity.activities where leftover.id != activity?.id {
            await leftover.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// What the user's turn is gets in front of the run's progress, here and
    /// beside other apps' activities.
    private static func content(_ state: State) -> ActivityContent<State> {
        ActivityContent(state: state, staleDate: nil, relevanceScore: state.needsUser ? 100 : 50)
    }

    /// The alert for an update. Its text only shows on a paired Apple Watch; on
    /// the iPhone it's what opens the Dynamic Island, or drops the Lock Screen
    /// card down as a banner on an iPhone without one.
    private static func alert(for state: State) -> AlertConfiguration {
        AlertConfiguration(
            title: LocalizedStringResource(String.LocalizationValue(state.title)),
            body: LocalizedStringResource(String.LocalizationValue(state.detail)),
            sound: .default)
    }
}
