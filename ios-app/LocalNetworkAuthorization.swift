import Foundation
import Network
import UIKit
import dnssd

/// Raises the Local Network prompt, which RPPairing needs granted, by briefly
/// advertising and browsing a throwaway Bonjour service.
@MainActor
final class LocalNetworkAuthorization {
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var continuation: CheckedContinuation<Bool, Never>?
    private var observers: [NSObjectProtocol] = []

    /// The browser is waiting with PolicyDenied.
    private var policyDenied = false
    /// Answers "denied" unless the browser recovers first.
    private var pendingDenial: DispatchWorkItem?
    /// The app went inactive after the denial, so the alert is probably up.
    private var awayForAlert = false

    // Must be in NSBonjourServices of the bundle the process runs as, or the
    // browse fails and reads as "denied". Inside LiveContainer that's
    // LiveContainer's Info.plist, which lists StikPair's probe type but not one
    // of ours, so we use StikPair's (ours lists it too).
    private let probeType = "_stikpairprobe._tcp"

    // iOS can report PolicyDenied before the alert is on screen or answered
    // (TN3179), so a denial only counts once it outlasts this...
    private let denialGrace: TimeInterval = 2
    // ...or this, once the user is back from the alert, so an Allow has time
    // to restart the browse.
    private let afterAlertGrace: TimeInterval = 4

    func request(timeout: TimeInterval = 60) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            self.continuation = cont

            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let listener = try? NWListener(using: params)
            listener?.service = NWListener.Service(name: "SideInstallerProbe", type: probeType)
            listener?.newConnectionHandler = { $0.cancel() }
            listener?.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    MainActor.assumeIsolated { self?.finish(false) }
                }
            }
            self.listener = listener

            let browser = NWBrowser(for: .bonjour(type: probeType, domain: nil), using: params)
            browser.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated { self?.browserChanged(state) }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                if !results.isEmpty {
                    MainActor.assumeIsolated { self?.finish(true) }
                }
            }
            self.browser = browser

            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.appResigned() }
                },
                center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.appActivated() }
                },
            ]

            listener?.start(queue: .main)
            browser.start(queue: .main)

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                MainActor.assumeIsolated { self?.finish(false) }
            }
        }
    }

    private func browserChanged(_ state: NWBrowser.State) {
        switch state {
        case .failed:
            finish(false)
        case let .waiting(error):
            // A denial arrives as waiting, not failed.
            guard case let .dns(code) = error, Int(code) == kDNSServiceErr_PolicyDenied else { return }
            if !policyDenied {
                policyDenied = true
                awayForAlert = false
                scheduleDenial(after: denialGrace)
            }
        case .ready:
            // Allowed after all; the browse results will confirm it.
            policyDenied = false
            awayForAlert = false
            cancelDenial()
        default:
            break
        }
    }

    private func appResigned() {
        // The alert is coming up: wait for the user's answer instead.
        guard policyDenied else { return }
        awayForAlert = true
        cancelDenial()
    }

    private func appActivated() {
        guard policyDenied, awayForAlert else { return }
        awayForAlert = false
        scheduleDenial(after: afterAlertGrace)
    }

    private func scheduleDenial(after delay: TimeInterval) {
        cancelDenial()
        // With the app inactive the alert may be up; appActivated reschedules.
        guard UIApplication.shared.applicationState == .active else {
            awayForAlert = true
            return
        }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.policyDenied else { return }
                self.finish(false)
            }
        }
        pendingDenial = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelDenial() {
        pendingDenial?.cancel()
        pendingDenial = nil
    }

    private func finish(_ authorized: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: authorized)
        cancelDenial()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        browser?.cancel(); browser = nil
        listener?.cancel(); listener = nil
    }
}
