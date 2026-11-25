import Foundation
import Testing
@testable import SideInstaller

private let lillq = "https://anisette.lillq.me"
private let sideStoreNew = "https://new.ani.sidestore.io"
private let jkcoxsonMac = "https://mac-ani.jkcoxson.com"
private let windows = "https://win.ani.sidestore.io"
private let android = "https://ani.sidestore.io"

@Suite("Anisette servers")
struct AnisetteServerTests {
    private let servers = AnisetteServer.bundledDefaults

    @Test("lillq is the default, on the list, and its own library")
    func lillqIsTheDefault() {
        #expect(AnisetteServer.fallback.address == lillq)
        #expect(servers.contains { $0.address == lillq })
        #expect(AnisetteServer.library(of: lillq) == .pool)
        #expect(AnisetteServer.library(of: lillq + "/") == .pool)
        #expect(AnisetteServer.library(of: sideStoreNew) == .mac)
        // It reports the Mac the macOS servers report.
        #expect(AnisetteServer.ADILibrary.pool.client == .mac)
    }

    @Test("A first sign-in starts on lillq, then the macOS servers, then Windows")
    func firstSignIn() {
        let order = AnisetteServer.candidates(pick: AnisetteServer.fallback.address, servers: servers)
        #expect(order.first == lillq)
        #expect(order.dropFirst().first == sideStoreNew)
        #expect(order.filter { $0 == lillq }.count == 1)
        #expect(!order.contains(android))
        let kinds = order.map { AnisetteServer.library(of: $0, in: servers) }
        #expect(kinds.firstIndex(of: .windows)! > kinds.lastIndex(of: .mac)!)
    }

    /// Its saved token only works with the identity it was issued to, which
    /// the other macOS servers take and lillq doesn't.
    @Test("A macOS pick keeps its library ahead, then lillq")
    func macPick() {
        let order = AnisetteServer.candidates(pick: jkcoxsonMac, servers: servers)
        #expect(order.first == jkcoxsonMac)
        let lillqAt = order.firstIndex(of: lillq)!
        #expect(order[..<lillqAt].allSatisfy { AnisetteServer.library(of: $0, in: servers) == .mac })
        #expect(order[(lillqAt + 1)...].allSatisfy { AnisetteServer.library(of: $0, in: servers) == .windows })
        #expect(order.contains(windows))
    }

    @Test("Any other pick goes first, then lillq")
    func otherPicks() {
        for pick in [android, windows] {
            let order = AnisetteServer.candidates(pick: pick, servers: servers)
            #expect(order.first == pick)
            let rest = order.dropFirst().filter { AnisetteServer.library(of: $0, in: servers) != .windows }
            #expect(rest.first == lillq, "\(pick)")
        }
    }

    @Test("lillq failing lately still leads its own group")
    func failingLillq() {
        let order = AnisetteServer.candidates(pick: lillq, servers: servers, failing: [lillq])
        #expect(order.first == lillq)
        // A macOS server failing waits behind the others of its library.
        let order2 = AnisetteServer.candidates(pick: lillq, servers: servers, failing: [sideStoreNew])
        #expect(order2.dropFirst().first != sideStoreNew)
    }

    @Test("Only lillq can use the identity lillq signed in with")
    func handOffServers() {
        let fromLillq = AnisetteServer.sameLibrary(
            asFirstOf: AnisetteServer.candidates(pick: lillq, servers: servers), in: servers)
        #expect(fromLillq == [lillq])
        let fromMac = AnisetteServer.sameLibrary(
            asFirstOf: AnisetteServer.candidates(pick: sideStoreNew, servers: servers), in: servers)
        #expect(fromMac.first == sideStoreNew)
        #expect(!fromMac.contains(lillq))
    }

    @Test("A token Apple refuses through lillq rules out lillq, not the macOS servers")
    func tokenRefusal() {
        var refusals = AnisetteServer.AppleRefusals(servers: servers)
        refusals.recordTokenRefusal(lillq)
        #expect(refusals.rulesOut(lillq))
        #expect(!refusals.rulesOut(sideStoreNew))
        // 503s go by the device reported, which is the same Mac.
        var outdated = AnisetteServer.AppleRefusals(servers: servers)
        outdated.recordOutdated(lillq)
        #expect(outdated.rulesOut(sideStoreNew))
        #expect(!outdated.rulesOut(windows))
    }

    @Test("SideStore keeps lillq when it was picked there")
    func sideStoreKeepsLillq() {
        var prefs: [String: Any] = ["useOnDeviceAnisette": false, "disableAnisetteRotation": true,
                                    "menuAnisetteURL": lillq,
                                    "customAnisetteClientInfo": SideStoreAnisetteHandoff.clientInfo]
        #expect(SideStoreAnisetteHandoff.applySettings(to: &prefs).isEmpty)
        #expect(prefs["menuAnisetteURL"] as? String == lillq)
        prefs["menuAnisetteURL"] = android
        _ = SideStoreAnisetteHandoff.applySettings(to: &prefs)
        #expect(prefs["menuAnisetteURL"] as? String == sideStoreNew)
    }

    @Test("SideStore is given a Mac that says “Mac OS X” unless it has a working one")
    func sideStoreClientInfo() {
        let handoff = SideStoreAnisetteHandoff.self
        #expect(handoff.clientInfo.contains("<Mac OS X;26.6;"))
        #expect(!handoff.clientInfo.contains("<macOS;"))
        let replaced = [
            nil,  // none saved: SideStore's default says “macOS”, which gets 503s
            "",
            "<MacBookPro18,3> <macOS;26.6;25F84> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
            "<MacBookPro13,3> <Mac OS X;10.12.6;16G29> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
            "<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKit/1 (com.apple.iTunes/12.12.4.1)>",
            "<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
        ]
        for saved in replaced {
            var prefs: [String: Any] = ["useOnDeviceAnisette": false, "disableAnisetteRotation": true,
                                        "menuAnisetteURL": sideStoreNew]
            if let saved { prefs["customAnisetteClientInfo"] = saved }
            #expect(handoff.applySettings(to: &prefs).count == 1, "\(saved ?? "none")")
            #expect(prefs["customAnisetteClientInfo"] as? String == handoff.clientInfo)
            #expect(prefs["customAnisetteUserAgent"] as? String == handoff.userAgent)
        }
        // The SideStore users' own fix, and a High Sierra Mac, stay as they are.
        for kept in ["<MacBookPro13,3> <Mac OS X;26.6;25F84> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
                     "<MacBookPro14,1> <Mac OS X;10.13.6;17G66> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
                     handoff.clientInfo] {
            var prefs: [String: Any] = ["useOnDeviceAnisette": false, "disableAnisetteRotation": true,
                                        "menuAnisetteURL": sideStoreNew,
                                        "customAnisetteClientInfo": kept,
                                        "customAnisetteUserAgent": "akd/1.0 CFNetwork/811.5.4 Darwin/16.7.0"]
            #expect(handoff.applySettings(to: &prefs).isEmpty, "\(kept)")
            #expect(prefs["customAnisetteClientInfo"] as? String == kept)
            #expect(prefs["customAnisetteUserAgent"] as? String == "akd/1.0 CFNetwork/811.5.4 Darwin/16.7.0")
        }
        #expect(!handoff.keepsClientInfo("<Mac15,7> <Mac OS X;10;x> <y>"))
        #expect(handoff.keepsClientInfo("<Mac15,7> <Mac OS X;27.2.1;26B131> <y>"))
    }
}
