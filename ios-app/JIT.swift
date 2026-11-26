import Foundation
import SwiftUI
import Darwin

// MARK: - How JIT stays on

/// How SideInstaller keeps JIT on for an app it opened under the debugger.
///
/// Being debugged marks a process, and up to iOS 18 that's all JIT needs: iOS
/// then lets it map memory that's writable and executable until it quits. From
/// iOS 26 the chips whose Trusted Execution Monitor guards code pages
/// (`JITDevice`) still refuse such memory, so an app asks the debugger to
/// prepare each region it wants to write code to, with a breakpoint, and the
/// debugger has to stay attached to answer. Apps ask in one of the ways
/// StikDebug's scripts answer, so the same ways are answered here, in Swift.
enum JITProtocol: Hashable {
    /// Attach, then let go at once.
    case detach
    /// Stay attached and answer the app's `brk #0xf00d` calls, `x16` saying
    /// which: 0 lets go of the app, 1 prepares a region (`x0` its address, or
    /// 0 to have one allocated, `x1` its size) and returns its address in
    /// `x0`. The calls StikDebug's universal script answers.
    case universal
    /// Stay attached until the app has had `regions` regions prepared with
    /// `brk #0x69` (`x0` the address, `x1` the size), then let go. The calls
    /// StikDebug's legacy script answers: UTM, DolphiniOS, Flycast and ARMSX2
    /// make one, maciOS three.
    case legacy(regions: Int)
    /// Geode's calls: `brk #0x69` prepares a region (64 KB when `x1` is 0),
    /// `#0x70` copies `x2` bytes of code from `x1` to `x0`, `#0x71` lets go.
    case geode

    /// True when the debugger stays attached while the app runs.
    var staysAttached: Bool { self != .detach }

    /// What the JIT page calls it.
    var title: String {
        switch self {
        case .detach: L("Attach and detach")
        case .universal: L("Universal")
        case .legacy: L("Legacy")
        case .geode: "Geode"
        }
    }

    /// What the log calls it.
    var logName: String {
        switch self {
        case .detach: "attach and detach"
        case .universal: "universal calls"
        case .legacy(let regions): "legacy calls, \(regions) region\(regions == 1 ? "" : "s")"
        case .geode: "Geode's calls"
        }
    }
}

/// What the JIT page offers for an app, kept per bundle ID.
enum JITMode: String, CaseIterable, Identifiable {
    /// The app's own way when it's a known app, on an iPhone that needs one.
    case automatic
    case detach
    case universal
    case legacy
    case geode

    var id: String { rawValue }
}

// MARK: - This device

/// Whether this iPhone needs JIT memory prepared by the debugger.
enum JITDevice {
    /// True from iOS 26 on the chips whose Trusted Execution Monitor guards
    /// code pages (A15 and M2 on), and from iOS 27 on all but the 2020 iPad
    /// Pros', as StikDebug tells them apart.
    static var preparesRegions: Bool {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        guard let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
                ?? ProblemReport.sysctlString("hw.machine") else {
            return major >= 27
        }
        return preparesRegions(model: model, osMajorVersion: major)
    }

    /// `preparesRegions` for a hardware model, e.g. "iPhone17,1", on an iOS
    /// major version.
    static func preparesRegions(model: String, osMajorVersion: Int) -> Bool {
        guard osMajorVersion >= 26 else { return false }
        let family = model.prefix { $0.isLetter }
        let numbers = model.dropFirst(family.count).split(separator: ",").compactMap { Int($0) }
        guard numbers.count == 2 else { return osMajorVersion >= 27 }
        let (major, minor) = (numbers[0], numbers[1])
        if osMajorVersion >= 27 {
            // The A12Z of the 2020 iPad Pros (iPad8,9–8,12) is the one without.
            return !(family == "iPad" && major == 8 && (9...12).contains(minor))
        }
        switch family {
        // iPhone14,x and iPad14,x are the first with A15 and M2.
        case "iPhone", "iPad": return major >= 14
        default: return false
        }
    }
}

// MARK: - Known apps

/// Apps known to ask for JIT one particular way, by name: the apps StikDebug
/// supports, and which of its scripts each is given.
enum JITApps {
    private static let known: [String: JITProtocol] = {
        var table: [String: JITProtocol] = [:]
        for name in ["Amethyst", "Andarium", "MeloNX", "XeniOS", "MeloCafé", "Manic EMU", "DukeX",
                     "TachyonU", "touchHLE", "HyperHLE", "Applesauce", "RPCS3", "AetherPS4",
                     "Husk", "Utsuro", "Henge"] {
            table[key(name)] = .universal
        }
        for name in ["UTM", "DolphiniOS", "Flycast", "ARMSX2 iOS"] {
            table[key(name)] = .legacy(regions: 1)
        }
        table[key("maciOS")] = .legacy(regions: 3)
        table[key("Geode")] = .geode
        return table
    }()

    /// A name as the table is keyed: case and accents don't matter, so
    /// "MeloCafe" finds "MeloCafé".
    static func key(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func knownProtocol(forName name: String) -> JITProtocol? {
        known[key(name)]
    }

    /// What `mode` comes to for an app called `appName`, on a device that does
    /// or doesn't need regions prepared.
    static func resolve(_ mode: JITMode, appName: String, preparesRegions: Bool) -> JITProtocol {
        switch mode {
        case .automatic:
            // Without TXM, being debugged is all an app needs.
            guard preparesRegions else { return .detach }
            // An app that isn't on the list most likely makes the universal
            // calls, which apps written for iOS 26 make.
            return knownProtocol(forName: appName) ?? .universal
        case .detach:
            return .detach
        case .universal:
            return .universal
        case .legacy:
            if case .legacy(let regions)? = knownProtocol(forName: appName) {
                return .legacy(regions: regions)
            }
            return .legacy(regions: 1)
        case .geode:
            return .geode
        }
    }
}

// MARK: - GDB remote protocol

/// The parts of GDB's remote serial protocol that JIT takes, as debugserver
/// speaks it on arm64.
enum GDBRemote {
    /// Register numbers debugserver uses: x0–x28 are 0–28, then fp, lr, sp, pc.
    static let pc = 32
    /// The page size of iOS on arm64, which regions are prepared a page at a
    /// time in.
    static let pageSize: UInt64 = 16_384

    /// The sum of a packet's bytes, as two hex digits.
    static func checksum(_ data: String) -> String {
        hexByte(data.utf8.reduce(UInt8(0)) { $0 &+ $1 })
    }

    /// A packet ready to send as it is: `$data#checksum`.
    static func frame(_ data: String) -> String {
        "$\(data)#\(checksum(data))"
    }

    static func hexByte(_ value: UInt8) -> String {
        let digits = String(value, radix: 16)
        return digits.count == 1 ? "0" + digits : digits
    }

    /// A register's value as debugserver reads and writes them: 8 bytes in
    /// memory order (little-endian), in hex.
    static func littleEndianHex(_ value: UInt64) -> String {
        (0..<8).map { hexByte(UInt8(truncatingIfNeeded: value >> (8 * UInt64($0)))) }.joined()
    }

    /// Reads bytes in memory order back into a number: a register (8 bytes)
    /// or an instruction (4). Nil when it isn't whole bytes of hex.
    static func littleEndianValue<S: StringProtocol>(_ hex: S) -> UInt64? {
        let digits = Array(hex.utf8)
        guard !digits.isEmpty, digits.count % 2 == 0, digits.count <= 16 else { return nil }
        var value: UInt64 = 0
        for index in stride(from: 0, to: digits.count, by: 2) {
            guard let high = nibble(digits[index]), let low = nibble(digits[index + 1]) else { return nil }
            value |= UInt64(high << 4 | low) << (UInt64(index / 2) * 8)
        }
        return value
    }

    private static func nibble(_ character: UInt8) -> UInt8? {
        switch character {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return character - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return character - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return character - UInt8(ascii: "A") + 10
        default: return nil
        }
    }

    /// The immediate of a `brk #imm` instruction, nil for any other.
    static func brkImmediate(_ instruction: UInt32) -> UInt16? {
        guard instruction & 0xFFE0_001F == 0xD420_0000 else { return nil }
        return UInt16(truncatingIfNeeded: instruction >> 5)
    }

    /// How many pages `size` bytes reach into.
    static func pageCount(_ size: UInt64) -> Int {
        size == 0 ? 0 : Int((size - 1) / pageSize + 1)
    }

    /// The write that prepares the page at `address`: one byte, 0x69, at its
    /// start (what StikDebug's `prepare_memory_region` writes), framed.
    static func pageWrite(at address: UInt64) -> String {
        frame("M\(String(address, radix: 16)),1:69")
    }
}

/// debugserver's answer to an attach or a continue: why the app stopped, with
/// the stopped thread's registers, or that it's gone.
struct GDBStopReply: Equatable {
    enum Reason: Equatable {
        /// Stopped on this signal: a breakpoint's is SIGTRAP (5).
        case signal(UInt8)
        /// Quit, with this exit status.
        case exited(UInt8)
        /// Ended by this signal.
        case killed(UInt8)
    }

    let reason: Reason
    /// The stopped thread, as debugserver names it (hex).
    let thread: String?
    /// The registers the stop came with, by number (`GDBRemote.pc`).
    let registers: [Int: UInt64]

    /// Nil for anything that isn't a stop reply (`T05thread:…;00:…;`, `S05`,
    /// `W00`, `X09`).
    init?(_ reply: String) {
        guard let kind = reply.first else { return nil }
        let code = reply.dropFirst().prefix(2)
        guard code.count == 2, let number = UInt8(code, radix: 16) else { return nil }
        var thread: String?
        var registers: [Int: UInt64] = [:]
        switch kind {
        case "W":
            reason = .exited(number)
        case "X":
            reason = .killed(number)
        case "S":
            reason = .signal(number)
        case "T":
            reason = .signal(number)
            for field in reply.dropFirst(3).split(separator: ";") {
                guard let colon = field.firstIndex(of: ":") else { continue }
                let key = field[..<colon]
                let value = field[field.index(after: colon)...]
                if key == "thread" {
                    thread = String(value)
                    continue
                }
                // Registers go by their number in hex; every other key is a word.
                guard key.count <= 2, let register = Int(key, radix: 16),
                      let registerValue = GDBRemote.littleEndianValue(value) else { continue }
                registers[register] = registerValue
            }
        default:
            return nil
        }
        self.thread = thread
        self.registers = registers
    }
}

// MARK: - Session

/// One app opened under the debugger to turn JIT on for it, from launch to
/// letting go.
///
/// Runs on a thread of its own over a tunnel of its own, a second
/// `DeviceConnection`, as StikDebug opens a fresh tunnel for each session: the
/// other pages open a fresh tunnel on the shared connection for each thing
/// they do, which would end a session held on it, and one that stays attached
/// lasts as long as the app runs.
final class JITSession: @unchecked Sendable {

    enum Phase: Equatable {
        case connecting
        case launching
        case attaching
        /// JIT is on, and the debugger stays attached answering the app.
        case attached
        case ended(Outcome)

        var isEnded: Bool {
            if case .ended = self { return true }
            return false
        }
    }

    enum Outcome: Equatable {
        /// JIT is on and the debugger let go: at once, or once the app had
        /// what it asked for.
        case detached(afterServing: Bool)
        /// The app quit, or was quit, before the debugger let go.
        case appEnded
        case failed(String)
    }

    enum Event {
        case phase(Phase)
        /// A region of this many bytes was prepared for the app.
        case prepared(UInt64)
    }

    let bundleID: String
    let name: String
    let jitProtocol: JITProtocol
    private let deviceIP: String
    private let pairingFilePath: String
    private let onEvent: @MainActor (Event) -> Void

    /// Guards what `quit` reads from another thread.
    private let lock = NSLock()
    private var debug: DebugServerSession?
    private var pid: UInt64?
    private var quitRequested = false

    /// Signals handed on to the app, for the log.
    private var signalsPassed = 0
    /// How many writes go out before their answers are read, when a region
    /// is prepared (as StikDebug batches them).
    private static let writesPerRound = 128
    /// Larger than any region an app means to ask for: a size past it is a
    /// garbled register, not a region.
    private static let largestRegion: UInt64 = 32 << 30
    /// The most a Geode copy may move, as Geode's script allows.
    private static let largestCopy: UInt64 = 0x40_0000

    /// `onEvent` runs on the main thread, in order.
    init(bundleID: String, name: String, jitProtocol: JITProtocol, deviceIP: String,
         pairingFilePath: String, onEvent: @escaping @MainActor (Event) -> Void) {
        self.bundleID = bundleID
        self.name = name
        self.jitProtocol = jitProtocol
        self.deviceIP = deviceIP
        self.pairingFilePath = pairingFilePath
        self.onEvent = onEvent
    }

    func start() {
        let thread = Thread { [self] in run() }
        thread.name = "sideinstaller.jit"
        // The app waits at each request until it's answered.
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    /// Quits the app, which ends the session: the debugger can't let go of an
    /// app that's still asking for memory without it crashing at its next
    /// request. Before the app has opened, the session stops before opening it.
    func quit() {
        lock.lock()
        quitRequested = true
        let debug = debug
        let pid = pid
        lock.unlock()
        guard let debug, let pid else { return }
        let name = name
        // Not on the main thread: DVT answers over the tunnel.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try debug.kill(pid: pid)
            } catch {
                Engine.shared.log("JIT: couldn't quit \(name) (\(error)).")
            }
        }
    }

    private var isQuitting: Bool {
        lock.lock()
        defer { lock.unlock() }
        return quitRequested
    }

    private func report(_ event: Event) {
        let onEvent = onEvent
        DispatchQueue.main.async {
            MainActor.assumeIsolated { onEvent(event) }
        }
    }

    private func log(_ message: String) {
        Engine.shared.log(message)
    }

    private func run() {
        let outcome: Outcome
        do {
            outcome = try openAndServe()
        } catch {
            outcome = .failed(describe(error))
            log("⛔️ JIT: \(Self.text(error))")
        }
        lock.lock()
        debug = nil
        lock.unlock()
        if signalsPassed > 0 {
            log("JIT: handed \(name) \(signalsPassed) signal(s) of its own while attached.")
        }
        report(.phase(.ended(outcome)))
    }

    private func openAndServe() throws -> Outcome {
        report(.phase(.connecting))
        let connection = DeviceConnection()
        defer { connection.disconnect() }
        try connection.connect(deviceIP: deviceIP, pairingFilePath: pairingFilePath)
        let debug: DebugServerSession
        do {
            debug = try connection.openDebugSession()
        } catch {
            throw Failure.debugger(error)
        }
        defer { debug.close() }
        lock.lock()
        self.debug = debug
        let cancelled = quitRequested
        lock.unlock()
        if cancelled { return .appEnded }

        report(.phase(.launching))
        let pid: UInt64
        do {
            pid = try debug.launchSuspended(bundleID: bundleID)
        } catch {
            throw Failure.launch(error)
        }
        lock.lock()
        self.pid = pid
        let quitNow = quitRequested
        lock.unlock()
        log("JIT: opened \(name) suspended (PID \(pid)).")
        if quitNow {
            try? debug.kill(pid: pid)
            return .appEnded
        }

        report(.phase(.attaching))
        startWithoutAcknowledgements(debug)
        let answer = try debug.send("vAttach;\(String(pid, radix: 16))") ?? ""
        guard let stop = GDBStopReply(answer), case .signal = stop.reason else {
            throw Failure.attach(answer)
        }
        log("JIT: attached to \(name) (\(jitProtocol.logName)).")
        guard jitProtocol.staysAttached else {
            detach(debug)
            return .detached(afterServing: false)
        }
        connection.startDebugHeartbeat(deviceIP: deviceIP)
        report(.phase(.attached))
        do {
            return try serve(debug)
        } catch let failure as Failure {
            throw failure
        } catch {
            // Quitting the app can close the connection under the wait.
            if isQuitting { return .appEnded }
            throw Failure.lost(error)
        }
    }

    /// debugserver acknowledges every packet until told not to. StikDebug opens
    /// it the same way and goes on whatever it answers.
    private func startWithoutAcknowledgements(_ debug: DebugServerSession) {
        do {
            try debug.sendAck()
            try debug.sendAck()
            let answer = try debug.send("QStartNoAckMode")
            if answer != "OK" {
                log("JIT: debugserver answered QStartNoAckMode with \(answer ?? "nothing").")
            }
        } catch {
            log("JIT: QStartNoAckMode failed (\(error)). Going on.")
        }
        debug.setAcknowledgements(false)
    }

    private func detach(_ debug: DebugServerSession) {
        do {
            let answer = try debug.send("D")
            log("JIT: let go of \(name) (\(answer ?? "no answer")).")
        } catch {
            log("JIT: letting go of \(name) failed (\(error)).")
        }
    }

    // MARK: Serving the app

    private enum Action {
        /// Carry on, with nothing for the app.
        case resume
        /// Carry on, handing the app the signal it stopped on.
        case pass(signal: UInt8, thread: String)
        /// Let go of the app.
        case detach
    }

    /// Runs the app until it lets the debugger go, quits, or is quit,
    /// answering each request it stops with.
    private func serve(_ debug: DebugServerSession) throws -> Outcome {
        var regionsLeft = Int.max
        if case .legacy(let regions) = jitProtocol { regionsLeft = regions }
        var unreadable = 0
        var answer = try resume(debug, "c")
        while true {
            guard let stop = GDBStopReply(answer) else {
                unreadable += 1
                guard unreadable < 5 else { throw Failure.unexpected(answer) }
                log("JIT: debugserver answered “\(answer.prefix(40))”. Continuing.")
                answer = try resume(debug, "c")
                continue
            }
            unreadable = 0
            switch stop.reason {
            case .exited(let status):
                log("JIT: \(name) quit (exit status \(status)).")
                return .appEnded
            case .killed(let signal):
                log("JIT: \(name) ended on signal \(signal).")
                return .appEnded
            case .signal(let signal):
                switch try act(on: stop, signal: signal, debug, regionsLeft: &regionsLeft) {
                case .resume:
                    answer = try resume(debug, "c")
                case .pass(let signal, let thread):
                    signalsPassed += 1
                    answer = try resume(debug, "vCont;S\(GDBRemote.hexByte(signal)):\(thread)")
                case .detach:
                    detach(debug)
                    return .detached(afterServing: true)
                }
            }
        }
    }

    /// Continues the app and waits until it stops. What it prints comes as O
    /// packets ahead of the stop.
    private func resume(_ debug: DebugServerSession, _ command: String) throws -> String {
        var answer = try debug.send(command) ?? ""
        while answer.hasPrefix("O"), answer != "OK" {
            answer = try debug.readResponse() ?? ""
        }
        return answer
    }

    /// What a stop asks for: a breakpoint this session answers, or a signal of
    /// the app's own.
    private func act(on stop: GDBStopReply, signal: UInt8, _ debug: DebugServerSession,
                     regionsLeft: inout Int) throws -> Action {
        guard let thread = stop.thread else { return .resume }
        let registers = Registers(stop: stop, thread: thread, debug: debug)
        guard let pc = try registers.value(GDBRemote.pc),
              let immediate = try brkImmediate(at: pc, debug) else {
            return pass(signal, thread)
        }
        switch jitProtocol {
        case .detach:
            return .detach
        case .universal:
            return try universalCall(immediate, signal: signal, pc: pc, registers)
        case .legacy:
            guard immediate == 0x69 else { return pass(signal, thread) }
            let address = try registers.value(0) ?? 0
            let size = try registers.value(1) ?? 0
            if address != 0 {
                try prepareRegion(at: address, size: size, debug)
            } else {
                log("JIT: \(name) asked for a region at address 0. Skipped.")
            }
            try registers.set(GDBRemote.pc, pc &+ 4)
            regionsLeft -= 1
            return regionsLeft > 0 ? .resume : .detach
        case .geode:
            return try geodeCall(immediate, signal: signal, pc: pc, registers)
        }
    }

    /// A signal that isn't a request goes on to the app, as it would without a
    /// debugger: a breakpoint of its own crashes it, as it would anyway. Not
    /// SIGINT or SIGSTOP, which are how a debugger stops an app itself.
    private func pass(_ signal: UInt8, _ thread: String) -> Action {
        if signal == 0 || signal == UInt8(SIGINT) || signal == UInt8(SIGSTOP) { return .resume }
        return .pass(signal: signal, thread: thread)
    }

    private func universalCall(_ immediate: UInt16, signal: UInt8, pc: UInt64,
                               _ registers: Registers) throws -> Action {
        let debug = registers.debug
        switch immediate {
        case 0xf00d:
            try registers.set(GDBRemote.pc, pc &+ 4)
            let call = try registers.value(16) ?? .max
            switch call {
            case 0:
                return .detach
            case 1:
                let requested = try registers.value(0) ?? 0
                let size = try registers.value(1) ?? 0
                guard requested != 0 || size != 0 else { return .resume }
                var address = requested
                if address == 0 {
                    guard let allocated = try allocateExecutable(size: size, debug) else { return .resume }
                    address = allocated
                }
                try prepareRegion(at: address, size: size, debug)
                try registers.set(0, address)
                return .resume
            case 2:
                log("JIT: \(name) sent the debugger a script to run (brk #0xf00d, x16 = 2). SideInstaller doesn't run scripts, so it's skipped.")
                return .resume
            default:
                log("JIT: \(name) made JIT call \(call), which SideInstaller doesn't know. Skipped.")
                return .resume
            }
        case 0x68:
            try registers.set(GDBRemote.pc, pc &+ 4)
            log("JIT: \(name) sent the debugger a script to run (brk #0x68). SideInstaller doesn't run scripts, so it's skipped.")
            return .resume
        case 0x69:
            try registers.set(GDBRemote.pc, pc &+ 4)
            // What StikDebug's universal script answers the legacy call with,
            // so an app that makes both moves on to the calls above.
            try registers.set(0, 0xE000_0069)
            log("JIT: \(name) made the legacy JIT call (brk #0x69), which Universal answers with an error. If it doesn't start, pick Legacy for it on the JIT page.")
            return .resume
        default:
            return pass(signal, registers.thread)
        }
    }

    private func geodeCall(_ immediate: UInt16, signal: UInt8, pc: UInt64,
                           _ registers: Registers) throws -> Action {
        let debug = registers.debug
        switch immediate {
        case 0x69:
            let address = try registers.value(0) ?? 0
            let size = try registers.value(1) ?? 0
            try prepareRegion(at: address, size: size > 0 ? size : 0x10000, debug)
            try registers.set(GDBRemote.pc, pc &+ 4)
            return .resume
        case 0x70:
            let destination = try registers.value(0) ?? 0
            let source = try registers.value(1) ?? 0
            let size = try registers.value(2) ?? 0
            if size > Self.largestCopy {
                log("JIT: \(name) asked to copy \(size) bytes, more than Geode's script allows. Skipped.")
            } else {
                try copyCode(from: source, to: destination, size: size, debug)
            }
            try registers.set(GDBRemote.pc, pc &+ 4)
            return .resume
        case 0x71:
            try registers.set(GDBRemote.pc, pc &+ 4)
            return .detach
        default:
            return pass(signal, registers.thread)
        }
    }

    /// The instruction at `pc`, as a breakpoint's immediate: nil when it isn't
    /// a breakpoint.
    private func brkImmediate(at pc: UInt64, _ debug: DebugServerSession) throws -> UInt16? {
        let answer = try debug.send("m\(String(pc, radix: 16)),4") ?? ""
        guard answer.utf8.count == 8, let instruction = GDBRemote.littleEndianValue(answer) else {
            return nil
        }
        return GDBRemote.brkImmediate(UInt32(truncatingIfNeeded: instruction))
    }

    /// Readies a region for the app to write code to and run it: the debugger
    /// writes a byte at the start of each of its pages, as StikDebug's
    /// `prepare_memory_region` does. The writes go out a round at a time, then
    /// their answers are read.
    private func prepareRegion(at address: UInt64, size: UInt64, _ debug: DebugServerSession) throws {
        guard size > 0 else { return }
        guard size <= Self.largestRegion, address <= UInt64.max - size else {
            log("JIT: \(name) asked for \(size) bytes at 0x\(String(address, radix: 16)), more than any region. Skipped.")
            return
        }
        let pages = GDBRemote.pageCount(size)
        var refused = 0
        var first = 0
        while first < pages {
            let count = min(Self.writesPerRound, pages - first)
            let packets = (first..<first + count).map { page in
                GDBRemote.pageWrite(at: address + UInt64(page) * GDBRemote.pageSize)
            }
            try debug.sendRaw(Array(packets.joined().utf8))
            for _ in 0..<count {
                if try debug.readResponse() != "OK" { refused += 1 }
            }
            first += count
        }
        report(.prepared(size))
        let refusal = refused > 0 ? ", \(refused) of them refused" : ""
        log("JIT: prepared \(Self.format(size)) at 0x\(String(address, radix: 16)) for \(name) (\(pages) pages\(refusal)).")
    }

    /// Has debugserver allocate `size` bytes the app can run, for a universal
    /// call that leaves the address to the debugger.
    private func allocateExecutable(size: UInt64, _ debug: DebugServerSession) throws -> UInt64? {
        let answer = try debug.send("_M\(String(size, radix: 16)),rx") ?? ""
        guard !answer.hasPrefix("E"), let address = UInt64(answer, radix: 16), address != 0 else {
            log("JIT: debugserver couldn't allocate \(Self.format(size)) for \(name) (\(answer.isEmpty ? "no answer" : answer)).")
            return nil
        }
        return address
    }

    /// Geode's patching call: code copied from `source` to `destination` by
    /// the debugger, which may write where the app can't, 16 KB at a time.
    private func copyCode(from source: UInt64, to destination: UInt64, size: UInt64,
                          _ debug: DebugServerSession) throws {
        let chunk: UInt64 = 0x4000
        var offset: UInt64 = 0
        while offset < size {
            let length = min(chunk, size - offset)
            let bytes = try debug.send("m\(String(source &+ offset, radix: 16)),\(String(length, radix: 16))") ?? ""
            guard bytes.utf8.count == Int(length) * 2, bytes.allSatisfy(\.isHexDigit) else {
                log("JIT: couldn't read \(name)'s code at 0x\(String(source &+ offset, radix: 16)) (\(bytes.prefix(8))). Copy stopped.")
                return
            }
            let written = try debug.send("M\(String(destination &+ offset, radix: 16)),\(String(length, radix: 16)):\(bytes)")
            guard written == "OK" else {
                log("JIT: couldn't write \(name)'s code at 0x\(String(destination &+ offset, radix: 16)) (\(written ?? "no answer")). Copy stopped.")
                return
            }
            offset += length
        }
        log("JIT: copied \(Self.format(size)) of \(name)'s code to 0x\(String(destination, radix: 16)).")
    }

    /// A stopped thread's registers: those the stop came with, the rest read
    /// from debugserver.
    private struct Registers {
        let stop: GDBStopReply
        let thread: String
        let debug: DebugServerSession

        func value(_ number: Int) throws -> UInt64? {
            if let value = stop.registers[number] { return value }
            let answer = try debug.send("p\(String(number, radix: 16));thread:\(thread);") ?? ""
            return GDBRemote.littleEndianValue(answer)
        }

        func set(_ number: Int, _ value: UInt64) throws {
            let answer = try debug.send(
                "P\(String(number, radix: 16))=\(GDBRemote.littleEndianHex(value));thread:\(thread);")
            if answer != "OK" {
                Engine.shared.log("JIT: debugserver didn't set register \(number) (\(answer ?? "no answer")).")
            }
        }
    }

    // MARK: Failures

    /// Where a session failed, for what the page says.
    private enum Failure: Error {
        /// The debugger or DVT didn't open: no disk image, or Developer Mode off.
        case debugger(Error)
        case launch(Error)
        /// debugserver's answer to the attach.
        case attach(String)
        /// The connection failed while the debugger was attached.
        case lost(Error)
        /// debugserver kept answering with something that isn't a stop.
        case unexpected(String)
    }

    private func describe(_ error: Error) -> String {
        guard let failure = error as? Failure else { return Self.text(error) }
        switch failure {
        case .debugger(let cause):
            return L("Couldn't reach the debugger on this iPhone: %@", Self.text(cause))
        case .launch(let cause):
            return L("Couldn't open %@ under the debugger: %@", name, Self.text(cause))
        case .attach(let answer):
            return L("The debugger couldn't attach to %@ (%@). Install it again with SideStore or SideInstaller, which sign apps so a debugger can attach.",
                     name, answer.isEmpty ? "—" : answer)
        case .lost(let cause):
            return L("The debugger lost %@ (%@). Open it with JIT again.", name, Self.text(cause))
        case .unexpected(let answer):
            return L("The debugger lost %@ (%@). Open it with JIT again.", name, String(answer.prefix(40)))
        }
    }

    static func text(_ error: Error) -> String {
        if let failure = error as? Failure {
            switch failure {
            case .debugger(let cause), .launch(let cause), .lost(let cause): return text(cause)
            case .attach(let answer), .unexpected(let answer): return "debugserver answered “\(answer.prefix(40))”"
            }
        }
        return (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    static func format(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
    }
}

// MARK: - Installed apps that can have JIT

/// An installed app a debugger can attach to, so one that can have JIT: one
/// signed for development, with `get-task-allow`, as SideStore and
/// SideInstaller sign apps.
struct JITApp: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let version: String?

    var id: String { bundleID }

    /// Nil unless the app's signature lets a debugger attach.
    init?(plist: [String: Any]) {
        guard let bundleID = plist["CFBundleIdentifier"] as? String, !bundleID.isEmpty,
              let entitlements = plist["Entitlements"] as? [String: Any],
              entitlements["get-task-allow"] as? Bool == true else { return nil }
        self.init(bundleID: bundleID,
                  name: Self.name(of: plist) ?? bundleID,
                  version: plist["CFBundleShortVersionString"] as? String)
    }

    init(bundleID: String, name: String, version: String?) {
        self.bundleID = bundleID
        self.name = name
        self.version = version
    }

    private static func name(of plist: [String: Any]) -> String? {
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let name = plist[key] as? String, !name.isEmpty { return name }
        }
        return nil
    }
}

// MARK: - Manager

/// Drives the JIT page: lists the apps that can have JIT, and runs one
/// session at a time. Only UI state lives here; the session does the device
/// work over its own tunnel, after the shared `Engine` has checked the link
/// and mounted the developer disk image.
@MainActor
final class JITManager: ObservableObject {

    /// The session on the page, from when it starts until it ends.
    struct Status: Equatable {
        let app: JITApp
        let jitProtocol: JITProtocol
        var phase: JITSession.Phase = .connecting
        /// JIT memory prepared for the app so far.
        var preparedBytes: UInt64 = 0
    }

    @Published private(set) var apps: [JITApp] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var isLoading = false
    /// True while the missing pairing file is generated, before the apps load
    /// or a session starts.
    @Published private(set) var isPairing = false
    /// The app being got ready for (disk image, device link) before its
    /// session starts.
    @Published private(set) var startingBundleID: String?
    /// The running session. Nil once it ends; its outcome is a popup.
    @Published private(set) var status: Status?
    @Published var lastError: String?
    @Published var lastSuccess: String?
    /// What was picked for each app, by bundle ID (`JITMode`'s raw values).
    @Published private var modes: [String: String] =
        UserDefaults.standard.dictionary(forKey: JITManager.modesKey) as? [String: String] ?? [:]

    private var session: JITSession?
    /// Which session's events count: one that ended may still have some on
    /// their way.
    private var sessionID: UUID?
    /// Silent audio, so SideInstaller isn't suspended while the app it opened
    /// is in front: a debugger that stops answering leaves the app frozen at
    /// its next request.
    private let keepAlive = KeepAlive()
    private var didAutoLoad = false
    private static let modesKey = "jitModes"

    private var engine: Engine { Engine.shared }

    /// True while a session is getting ready or running: one at a time.
    var isBusy: Bool { startingBundleID != nil || status != nil }

    // MARK: Popups

    /// How the last session went, as popups `RootView` stacks over the app.
    var popups: [ToolPopup] {
        [lastError.map(ToolPopup.error), lastSuccess.map(ToolPopup.success)].compactMap { $0 }
    }

    func closePopup(_ popup: ToolPopup) {
        switch popup {
        case .error:   lastError = nil
        case .success: lastSuccess = nil
        }
    }

    // MARK: Apps

    /// Loads once when the page opens with the tunnel up and a pairing file,
    /// without showing errors. Opening the page doesn't start LocalDevVPN or
    /// pair this iPhone; Load apps does.
    func autoLoad() {
        guard !didAutoLoad, !hasLoaded, !isLoading, engine.hasPairingFile else { return }
        engine.refreshNetworkStatus()
        guard engine.vpnConnected else { return }
        didAutoLoad = true
        load(quiet: true)
    }

    /// Asks the device which apps it has, generating the pairing file first
    /// when there's none. `quiet` logs failures instead of showing them, and
    /// never pairs, since pairing puts up popups.
    func load(quiet: Bool = false) {
        guard !isLoading else { return }
        isLoading = true
        if !quiet {
            lastError = nil
            engine.log("=== JIT: reading the device's apps ===")
        }
        Task {
            do {
                if !quiet { try await ensurePairingFile() }
                let own = Bundle.main.bundleIdentifier
                apps = try await engine.installedAppPlists()
                    .compactMap(JITApp.init(plist:))
                    // Debugging SideInstaller would stop SideInstaller.
                    .filter { $0.bundleID != own }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                hasLoaded = true
                engine.log("JIT: \(apps.count) app(s) a debugger can attach to.")
            } catch is CancellationError {
                // The pairing popups were closed: nothing to report.
                engine.log("JIT: pairing stopped.")
            } catch {
                let message = Self.text(error)
                if quiet {
                    engine.log("JIT: apps not loaded yet (\(message))")
                } else {
                    lastError = message
                    engine.log("⛔️ JIT: \(message)")
                }
            }
            isLoading = false
        }
    }

    func mode(for app: JITApp) -> JITMode {
        modes[app.bundleID].flatMap(JITMode.init(rawValue:)) ?? .automatic
    }

    func setMode(_ mode: JITMode, for app: JITApp) {
        modes[app.bundleID] = mode == .automatic ? nil : mode.rawValue
        UserDefaults.standard.set(modes, forKey: Self.modesKey)
    }

    /// How JIT stays on for `app` here, with the mode picked for it.
    func jitProtocol(for app: JITApp) -> JITProtocol {
        JITApps.resolve(mode(for: app), appName: app.name, preparesRegions: JITDevice.preparesRegions)
    }

    // MARK: Sessions

    /// Opens `app` under the debugger with JIT on: checks the link, mounts
    /// the developer disk image if it isn't, then starts the session.
    func enable(_ app: JITApp) {
        guard !isBusy else { return }
        guard !engine.isRunning else {
            lastError = ErrorHelp.explained(L("An install is already running. Wait for it to finish, then try again."))
            return
        }
        lastError = nil
        lastSuccess = nil
        startingBundleID = app.bundleID
        let jitProtocol = jitProtocol(for: app)
        engine.log("=== JIT: \(app.name) (\(app.bundleID), \(jitProtocol.logName)) ===")
        Task {
            do {
                try await getReady()
                let deviceIP = engine.deviceHost
                let pairingFilePath = engine.pairingFilePath ?? PairingController.pairingFilePath()
                start(app, jitProtocol, deviceIP: deviceIP, pairingFilePath: pairingFilePath)
            } catch is CancellationError {
                engine.log("JIT: pairing stopped.")
            } catch {
                let message = Self.text(error)
                lastError = message
                engine.log("⛔️ JIT: \(message)")
            }
            startingBundleID = nil
        }
    }

    /// Quits the app the session is attached to, which ends the session.
    func quit() {
        session?.quit()
    }

    /// Developer Mode, the pairing file, the device link, and the developer
    /// disk image, which debugserver comes with.
    private func getReady() async throws {
        try requireDeveloperMode()
        try await ensurePairingFile()
        if !DeveloperDiskImage.isDownloaded {
            try await DeveloperDiskImage.downloadMissing { _ in }
        }
        // Mount progress goes to the activity log only.
        var lastLogged = -1
        try await engine.prepareDeveloperDiskImage { fraction in
            let step = Int(fraction * 4) * 25
            guard step > lastLogged else { return }
            lastLogged = step
            Engine.shared.log("DDI mount: \(step)%")
        }
    }

    private func requireDeveloperMode() throws {
        if Engine.developerModeIsOn == false {
            throw EngineError.message(ErrorHelp.explained(L("JIT needs Developer Mode. Turn it on under Settings › Privacy & Security › Developer Mode, and confirm it after the restart.")))
        }
    }

    /// Generates the pairing file when there's none, as the Pairing page's
    /// Generate button does and with the same popups, so JIT doesn't send
    /// anyone to that page first. Only iOS 27 on pairs with itself; below it,
    /// connecting reports the missing file as on every other page. Throws
    /// `CancellationError` when the popups are closed.
    private func ensurePairingFile() async throws {
        guard !engine.hasPairingFile, Engine.deviceCanSelfPair else { return }
        // Asked for before the pairing rather than after it: JIT can't go on
        // without them.
        try requireDeveloperMode()
        guard await engine.tunnelUp() else {
            throw EngineError.message(L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        engine.log("JIT: no pairing file yet, so pairing this iPhone with itself …")
        isPairing = true
        defer { isPairing = false }
        try await PairingManager.shared.generateForPage()
        engine.log("JIT: pairing file ready.")
    }

    private func start(_ app: JITApp, _ jitProtocol: JITProtocol, deviceIP: String,
                       pairingFilePath: String) {
        status = Status(app: app, jitProtocol: jitProtocol)
        // Before the launch, which puts the app in front.
        keepAlive.startAudio()
        let id = UUID()
        let session = JITSession(bundleID: app.bundleID, name: app.name, jitProtocol: jitProtocol,
                                 deviceIP: deviceIP, pairingFilePath: pairingFilePath) { [weak self] event in
            guard let self, self.sessionID == id else { return }
            self.handle(event)
        }
        self.session = session
        sessionID = id
        session.start()
    }

    private func handle(_ event: JITSession.Event) {
        switch event {
        case .phase(let phase):
            if case .ended(let outcome) = phase {
                end(outcome)
            } else {
                status?.phase = phase
            }
        case .prepared(let bytes):
            status?.preparedBytes += bytes
        }
    }

    private func end(_ outcome: JITSession.Outcome) {
        let name = status?.app.name ?? ""
        keepAlive.stopAudio()
        session = nil
        sessionID = nil
        status = nil
        switch outcome {
        case .detached(let afterServing):
            lastSuccess = afterServing
                ? L("%@ has the JIT memory it asked for, so SideInstaller let go of it. JIT stays on until it quits.", name)
                : L("JIT is on for %@ until it quits.", name)
            engine.log("JIT: on for \(name).")
        case .appEnded:
            engine.log("JIT: session for \(name) ended.")
        case .failed(let message):
            lastError = message
        }
    }

    private static func text(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}
