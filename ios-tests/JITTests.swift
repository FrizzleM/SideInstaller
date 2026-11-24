import Foundation
import Testing
@testable import SideInstaller

@Suite("JIT: GDB remote protocol")
struct GDBRemoteTests {

    @Test("Packets are framed with the sum of their bytes")
    func framing() {
        // The two every GDB server sends and takes.
        #expect(GDBRemote.frame("OK") == "$OK#9a")
        #expect(GDBRemote.frame("c") == "$c#63")
        #expect(GDBRemote.pageWrite(at: 0x1_1804_c000) == GDBRemote.frame("M11804c000,1:69"))
    }

    @Test("Registers are 8 bytes in memory order")
    func littleEndian() {
        #expect(GDBRemote.littleEndianHex(0x1_0000_4000) == "0040000001000000")
        #expect(GDBRemote.littleEndianHex(0xE000_0069) == "690000e000000000")
        #expect(GDBRemote.littleEndianValue("0040000001000000") == 0x1_0000_4000)
        #expect(GDBRemote.littleEndianValue("a00d20d4") == 0xD420_0DA0)
        #expect(GDBRemote.littleEndianValue("FFFFFFFFFFFFFFFF") == .max)
        for value: UInt64 in [0, 1, 0xf00d, 0x1_6fdf_f2c0, .max] {
            #expect(GDBRemote.littleEndianValue(GDBRemote.littleEndianHex(value)) == value)
        }
        // Not whole bytes, too long, or not hex.
        #expect(GDBRemote.littleEndianValue("") == nil)
        #expect(GDBRemote.littleEndianValue("abc") == nil)
        #expect(GDBRemote.littleEndianValue("00112233445566778899") == nil)
        #expect(GDBRemote.littleEndianValue("E08x") == nil)
    }

    @Test("Breakpoints are told by their encoding")
    func breakpoints() {
        // brk #imm16 is 0xD4200000 with the immediate in bits 5–20.
        #expect(GDBRemote.brkImmediate(0xD43E_01A0) == 0xf00d)
        #expect(GDBRemote.brkImmediate(0xD420_0D20) == 0x69)
        #expect(GDBRemote.brkImmediate(0xD420_0E20) == 0x71)
        #expect(GDBRemote.brkImmediate(0xD420_0020) == 1)
        // nop, svc #0x80, and hlt #0, which differs from brk in bit 22 only.
        #expect(GDBRemote.brkImmediate(0xD503_201F) == nil)
        #expect(GDBRemote.brkImmediate(0xD400_1001) == nil)
        #expect(GDBRemote.brkImmediate(0xD440_0000) == nil)
    }

    @Test("Regions are prepared a 16 KB page at a time")
    func pages() {
        #expect(GDBRemote.pageCount(0) == 0)
        #expect(GDBRemote.pageCount(1) == 1)
        #expect(GDBRemote.pageCount(16_384) == 1)
        #expect(GDBRemote.pageCount(16_385) == 2)
        #expect(GDBRemote.pageCount(64 << 20) == 4096)
    }

    @Test("A stop at a breakpoint brings its thread and registers")
    func stopReply() throws {
        let reply = "T05thread:1a2b;name:MeloNX;threads:1a2b,1a2c;thread-pcs:4c3d000001000000;"
            + "00:0000000000000000;01:0000000004000000;10:0100000000000000;"
            + "20:4c3d000001000000;metype:6;mecount:2;medata:1;medata:f00d;reason:exception;"
        let stop = try #require(GDBStopReply(reply))
        #expect(stop.reason == .signal(5))
        #expect(stop.thread == "1a2b")
        #expect(stop.registers[0] == 0)
        #expect(stop.registers[1] == 0x4_0000_0000)
        #expect(stop.registers[16] == 1)
        #expect(stop.registers[GDBRemote.pc] == 0x1_0000_3d4c)
        // Words aren't registers, however they look.
        #expect(stop.registers.count == 4)
    }

    @Test("Quitting and being killed end the session; anything else isn't a stop")
    func otherReplies() {
        #expect(GDBStopReply("W00")?.reason == .exited(0))
        #expect(GDBStopReply("W01;process:1f4")?.reason == .exited(1))
        #expect(GDBStopReply("X09")?.reason == .killed(9))
        #expect(GDBStopReply("S11")?.reason == .signal(17))
        #expect(GDBStopReply("S11")?.thread == nil)
        #expect(GDBStopReply("OK") == nil)
        #expect(GDBStopReply("E08") == nil)
        #expect(GDBStopReply("") == nil)
        #expect(GDBStopReply("T") == nil)
    }
}

@Suite("JIT: devices and apps")
struct JITResolutionTests {

    @Test("Only TXM's chips need regions prepared, from iOS 26")
    func devices() {
        // Up to iOS 18, being debugged is enough everywhere.
        #expect(!JITDevice.preparesRegions(model: "iPhone17,1", osMajorVersion: 18))
        // iOS 26: A15 and M2 on.
        #expect(!JITDevice.preparesRegions(model: "iPhone13,2", osMajorVersion: 26))
        #expect(JITDevice.preparesRegions(model: "iPhone14,5", osMajorVersion: 26))
        #expect(JITDevice.preparesRegions(model: "iPhone17,3", osMajorVersion: 26))
        #expect(!JITDevice.preparesRegions(model: "iPad13,4", osMajorVersion: 26))
        #expect(JITDevice.preparesRegions(model: "iPad14,3", osMajorVersion: 26))
        // iOS 27: all but the A12Z iPad Pros.
        #expect(JITDevice.preparesRegions(model: "iPhone12,1", osMajorVersion: 27))
        #expect(!JITDevice.preparesRegions(model: "iPad8,9", osMajorVersion: 27))
        #expect(!JITDevice.preparesRegions(model: "iPad8,12", osMajorVersion: 27))
        #expect(JITDevice.preparesRegions(model: "iPad13,18", osMajorVersion: 27))
        // A model that won't parse goes by the iOS version.
        #expect(JITDevice.preparesRegions(model: "arm64", osMajorVersion: 27))
        #expect(!JITDevice.preparesRegions(model: "arm64", osMajorVersion: 26))
    }

    @Test("Auto gives known apps their own way, and the rest the universal calls")
    func automatic() {
        func resolve(_ name: String, txm: Bool = true) -> JITProtocol {
            JITApps.resolve(.automatic, appName: name, preparesRegions: txm)
        }
        #expect(resolve("MeloNX", txm: false) == .detach)
        #expect(resolve("UTM", txm: false) == .detach)
        #expect(resolve("MeloNX") == .universal)
        #expect(resolve("melocafe") == .universal)
        #expect(resolve("MeloCafé") == .universal)
        #expect(resolve("UTM") == .legacy(regions: 1))
        #expect(resolve("ARMSX2 iOS") == .legacy(regions: 1))
        #expect(resolve("maciOS") == .legacy(regions: 3))
        #expect(resolve("Geode") == .geode)
        #expect(resolve("Some new emulator") == .universal)
    }

    @Test("A mode picked for an app wins")
    func picked() {
        #expect(JITApps.resolve(.detach, appName: "MeloNX", preparesRegions: true) == .detach)
        #expect(JITApps.resolve(.universal, appName: "UTM", preparesRegions: false) == .universal)
        #expect(JITApps.resolve(.legacy, appName: "maciOS", preparesRegions: true) == .legacy(regions: 3))
        #expect(JITApps.resolve(.legacy, appName: "Other", preparesRegions: true) == .legacy(regions: 1))
        #expect(JITApps.resolve(.geode, appName: "Other", preparesRegions: false) == .geode)
        #expect(!JITProtocol.detach.staysAttached)
        #expect(JITProtocol.legacy(regions: 1).staysAttached)
    }

    @Test("Only apps signed with get-task-allow are listed")
    func debuggableApps() throws {
        let app = try #require(JITApp(plist: [
            "CFBundleIdentifier": "com.example.emu",
            "CFBundleDisplayName": "Emu",
            "CFBundleShortVersionString": "1.2",
            "Entitlements": ["get-task-allow": true, "application-identifier": "TEAM.com.example.emu"],
        ]))
        #expect(app.name == "Emu")
        #expect(app.version == "1.2")
        // Its bundle name, then its bundle ID, when it has no display name.
        #expect(JITApp(plist: ["CFBundleIdentifier": "a.b", "CFBundleName": "B",
                               "Entitlements": ["get-task-allow": true]])?.name == "B")
        #expect(JITApp(plist: ["CFBundleIdentifier": "a.b",
                               "Entitlements": ["get-task-allow": true]])?.name == "a.b")
        // App Store and system apps can't be debugged.
        #expect(JITApp(plist: ["CFBundleIdentifier": "a.b",
                               "Entitlements": ["get-task-allow": false]]) == nil)
        #expect(JITApp(plist: ["CFBundleIdentifier": "a.b", "Entitlements": [String: Any]()]) == nil)
        #expect(JITApp(plist: ["CFBundleIdentifier": "a.b"]) == nil)
    }
}
