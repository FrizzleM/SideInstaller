import Foundation

/// What an Apple ID sign-in is for, as the log names it.
enum AppleSignInPurpose {
    /// The Install tab's run.
    case install
    /// Refreshing an installed app from Sideloaded apps.
    case refresh
    case certificates
    case entitlements
    /// Signing in for someone else's iPhone, often with their Apple ID.
    case sideBySide

    var name: String {
        switch self {
        case .install:      "Install"
        case .refresh:      "Sideloaded apps"
        case .certificates: "Certificates"
        case .entitlements: "Entitlements"
        case .sideBySide:   "Side by Side"
        }
    }
}

/// One Apple ID sign-in, from when it joins `AppleSignInQueue` until its turn
/// ends. It goes to Rust as the context of the 2FA and team callbacks, so each
/// question, and the answer to it, belongs to the sign-in that asked it.
final class AppleSignInTicket: @unchecked Sendable {
    let id: Int
    let purpose: AppleSignInPurpose
    /// The Apple ID signing in, which the 2FA sheet shows.
    let appleID: String
    /// The run an install's background sign-in belongs to (`Engine.finishedRuns`).
    let run: Int?

    private let lock = NSLock()
    private var cancelled = false
    private var teamCancelled = false

    init(id: Int, purpose: AppleSignInPurpose, appleID: String, run: Int?) {
        self.id = id
        self.purpose = purpose
        self.appleID = appleID
        self.run = run
    }

    /// True once one of this sign-in's 2FA requests ended without a code, so
    /// the sign-in stops instead of trying the next anisette server.
    var twoFactorWasCancelled: Bool {
        lock.withLock { cancelled }
    }

    func markTwoFactorCancelled() {
        lock.withLock { cancelled = true }
    }

    /// True once the question of which developer team signs ended without an
    /// answer, so the sign-in stops instead of trying the next anisette server.
    var teamQuestionWasCancelled: Bool {
        lock.withLock { teamCancelled }
    }

    func markTeamQuestionCancelled() {
        lock.withLock { teamCancelled = true }
    }

    /// This ticket as the 2FA and team callbacks' context. Unretained: the
    /// queue holds the ticket until its turn ends, after every call it's
    /// handed to.
    var context: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }

    /// The ticket a 2FA or team callback's context carries.
    static func from(context: UnsafeMutableRawPointer?) -> AppleSignInTicket? {
        context.map { Unmanaged<AppleSignInTicket>.fromOpaque($0).takeUnretainedValue() }
    }
}

/// Runs Apple ID sign-ins one at a time, first come first served.
///
/// The Install tab, Certificates, Entitlements and Side by Side each sign in on
/// their own, and can overlap: opening Certificates during an install starts a
/// second sign-in. Two at once each have Apple send a code to the same devices,
/// with no telling which is whose, and both write the anisette identities kept
/// in the sign-in folder. One at a time, each 2FA request belongs to the one
/// sign-in talking to Apple. And since the install, Certificates and
/// Entitlements reuse the developer session a sign-in saves
/// (`apple_session.rs`), the ones queued behind it usually skip 2FA.
@MainActor
final class AppleSignInQueue {
    private nonisolated let log: @Sendable (String) -> Void
    private var nextID = 1
    /// The sign-in whose turn it is.
    private var current: AppleSignInTicket?
    /// The sign-ins waiting, in order, each resumed when its turn comes.
    private var waiting: [(ticket: AppleSignInTicket, turn: CheckedContinuation<Void, Error>)] = []

    nonisolated init(log: @escaping @Sendable (String) -> Void) {
        self.log = log
    }

    /// Waits until the sign-ins queued ahead of this one are done, then returns
    /// its ticket, which holds the turn until `finished(_:)`: call that in a
    /// `defer` right after. If the task is cancelled first, it leaves the queue
    /// and throws `CancellationError`.
    func waitForTurn(_ purpose: AppleSignInPurpose, appleID: String,
                     run: Int? = nil) async throws -> AppleSignInTicket {
        try Task.checkCancellation()
        let ticket = AppleSignInTicket(id: nextID, purpose: purpose, appleID: appleID, run: run)
        nextID += 1
        guard let ahead = current else {
            current = ticket
            return ticket
        }
        log("\(purpose.name): another Apple ID sign-in is running (\(ahead.purpose.name)) — waiting for it to finish first.")
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (turn: CheckedContinuation<Void, Error>) in
                // Cancelled before joining the line, `leave` would find nothing.
                if Task.isCancelled {
                    turn.resume(throwing: CancellationError())
                } else {
                    waiting.append((ticket, turn))
                }
            }
        } onCancel: {
            Task { @MainActor in self.leave(ticket) }
        }
        return ticket
    }

    /// Ends `ticket`'s turn and gives it to the next sign-in in line.
    func finished(_ ticket: AppleSignInTicket) {
        guard current === ticket else { return }
        guard !waiting.isEmpty else {
            current = nil
            return
        }
        let next = waiting.removeFirst()
        current = next.ticket
        next.turn.resume()
    }

    /// Takes a cancelled sign-in out of the line. Does nothing once its turn
    /// has come: the sign-in then stops at its own cancellation check.
    private func leave(_ ticket: AppleSignInTicket) {
        guard let index = waiting.firstIndex(where: { $0.ticket === ticket }) else { return }
        waiting.remove(at: index).turn.resume(throwing: CancellationError())
    }
}

/// A sign-in's 2FA requests, answered from the two-factor sheet.
typealias TwoFactorRequests = SignInRequests<TwoFactorAnswer>

/// A sign-in's question of which developer team signs, answered with a team ID
/// from the team sheet.
typealias TeamRequests = SignInRequests<String>

/// Hands the request a sign-in is blocked on, a 2FA code or which team signs,
/// to the sheet, and the sheet's answer back to that request alone.
///
/// Each request has a number, which the sheet hands back with its answer, and
/// a semaphore of its own, so an answer can't reach a later request or another
/// sign-in's. `AppleSignInQueue` lets one sign-in talk to Apple at a time, so
/// one request waits at a time; one made while another waits is turned down
/// (`open` returns nil) rather than left with no sheet to answer it.
/// Thread-safe.
final class SignInRequests<Answer>: @unchecked Sendable {
    /// A request a sign-in is blocked on.
    final class Request: @unchecked Sendable {
        let id: Int
        let ticket: AppleSignInTicket
        fileprivate let reply = DispatchSemaphore(value: 0)
        /// Guarded by the owner's lock.
        fileprivate var answer: Answer?

        fileprivate init(id: Int, ticket: AppleSignInTicket) {
            self.id = id
            self.ticket = ticket
        }
    }

    private let lock = NSLock()
    private var nextID = 1
    /// The request waiting for the sheet, if any.
    private var waiting: Request?
    /// Marks the sign-in whose request was cancelled, so it stops instead of
    /// trying the next anisette server.
    private let markCancelled: (AppleSignInTicket) -> Void

    init(markingCancelled markCancelled: @escaping (AppleSignInTicket) -> Void) {
        self.markCancelled = markCancelled
    }

    /// Opens a request for `ticket`'s sign-in, or returns nil while another
    /// request waits.
    func open(for ticket: AppleSignInTicket) -> Request? {
        lock.withLock {
            guard waiting == nil else { return nil }
            let request = Request(id: nextID, ticket: ticket)
            nextID += 1
            waiting = request
            return request
        }
    }

    /// True while request `id` waits for an answer.
    func isWaiting(_ id: Int) -> Bool {
        lock.withLock { waiting?.id == id }
    }

    /// Blocks until `request` is answered or cancelled, and returns the answer,
    /// or nil when it was cancelled. Never on the main thread, which answers.
    func wait(_ request: Request) -> Answer? {
        request.reply.wait()
        return lock.withLock { request.answer }
    }

    /// Hands `answer` to request `id`. Returns false, doing nothing, once it
    /// isn't waiting: answered, cancelled, or another request's number.
    @discardableResult
    func answer(_ id: Int, with answer: Answer) -> Bool {
        let request: Request? = lock.withLock {
            guard let request = waiting, request.id == id else { return nil }
            waiting = nil
            request.answer = answer
            return request
        }
        request?.reply.signal()
        return request != nil
    }

    /// Ends request `id` without an answer, which stops its sign-in, and marks
    /// that sign-in cancelled so it doesn't move on to the next anisette
    /// server. Returns false once the request isn't waiting.
    @discardableResult
    func cancel(_ id: Int) -> Bool {
        let request: Request? = lock.withLock {
            guard let request = waiting, request.id == id else { return nil }
            waiting = nil
            return request
        }
        guard let request else { return false }
        markCancelled(request.ticket)
        request.reply.signal()
        return true
    }
}
