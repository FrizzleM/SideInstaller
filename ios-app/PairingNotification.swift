import os
import UIKit
import UserNotifications

/// This iPhone's pairing code as a notification: the stand-in for the Live
/// Activity in a build that shipped without the extension that draws it (see
/// `PairingLiveActivity.hasExtension`). Its banner lands over Settings the same
/// way, at the price of the system asking to allow notifications first.
///
/// A build that has the extension never asks: `PairingController` uses one of
/// the two, never both, and everything here that could bring the prompt up, or
/// post anything, checks `isFallback` again.
@MainActor
final class PairingNotification: PairingCodeSurface {

    static let shared = PairingNotification()

    /// True for a build with no extension to draw the Live Activity.
    nonisolated static var isFallback: Bool { !PairingLiveActivity.hasExtension }

    /// What the user has said about notifications, once that's been read.
    /// Behind a lock, since the guide's wording reads it from anywhere.
    private nonisolated static let permission =
        OSAllocatedUnfairLock<UNAuthorizationStatus?>(initialState: nil)

    /// True when the code can be expected over Settings as a notification:
    /// this build falls back on one, and the user hasn't refused them.
    nonisolated static var mayShow: Bool {
        isFallback && permission.withLock { $0 } != .denied
    }

    /// True when starting to pair will bring up the system's prompt.
    nonisolated static var willAsk: Bool {
        isFallback && permission.withLock { $0 } == .notDetermined
    }

    /// One identifier, so "Paired" replaces the code it follows.
    private static let identifier = "pairing"

    private var center: UNUserNotificationCenter { .current() }
    /// True from `start` to `finish`.
    private var pairing = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.activated() }
        }
    }

    /// At launch: drops a code left up by a run that was killed, and reads the
    /// permission for the guide. Never asks.
    func reset() {
        guard Self.isFallback else { return }
        clear()
        Task { await Self.readPermission() }
    }

    // MARK: Pairing's milestones

    /// Pairing has begun. The first time, this is where the system asks to
    /// allow notifications, and the only place it can.
    func start() {
        guard Self.isFallback else { return }
        pairing = true
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            await Self.readPermission()
        }
    }

    func show(code: String) {
        guard Self.isFallback else { return }
        // The code is the subtitle: a line of its own, under what it is.
        post(title: L("Pairing code"), subtitle: code,
             body: L("Type this into the prompt in Settings."))
    }

    /// A success says so, since the install only goes on from the app; anything
    /// else takes the code down, and the app explains.
    func finish(paired: Bool) {
        guard Self.isFallback, pairing else { return }
        pairing = false
        if paired, UIApplication.shared.applicationState != .active {
            post(title: L("Paired"), subtitle: "", body: L("Tap to return to SideInstaller."))
        } else {
            clear()
        }
    }

    // MARK: Helpers

    /// Back in the app. "Paired" has nothing left to say; a code stays while
    /// pairing goes on, for the trip back to Settings. The permission may have
    /// been changed in Settings meanwhile.
    private func activated() {
        guard Self.isFallback else { return }
        if !pairing { clear() }
        Task { await Self.readPermission() }
    }

    private func post(title: String, subtitle: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        // Refused, or not answered yet, and this does nothing: the popup in
        // the app still shows the code.
        center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil))
    }

    private func clear() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }

    private nonisolated static func readPermission() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        permission.withLock { $0 = status }
    }
}
