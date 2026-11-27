import Foundation
import Testing
@testable import SideInstaller

/// Which installed apps the Pairing page lists, and what each is handed.
@Suite("Pairing targets")
struct PairingTargetsTests {

    private func plist(_ dict: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    private func dictionary(_ data: Data) throws -> [String: Any] {
        try #require(try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])
    }

    private let remote: [String: Any] = [
        "public_key": Data(repeating: 1, count: 32),
        "private_key": Data(repeating: 2, count: 32),
        "identifier": "5A1D3C0E-0000-4000-8000-000000000000",
        "alt_irk": Data(repeating: 3, count: 16),
    ]

    private let lockdown: [String: Any] = [
        "HostCertificate": Data("host".utf8),
        "HostPrivateKey": Data("key".utf8),
        "DeviceCertificate": Data("device".utf8),
        "SystemBUID": "BUID",
        "UDID": "00008140-000000000000001C",
    ]

    @Test("ARMSX3 is listed by its name, whatever team its bundle id carries")
    func armsx3Listed() throws {
        let targets = PairingTargets.match(installed: [
            .init(bundleID: "com.armsx3.ARMSX3.X53M69UJ7U", displayName: "ARMSX3"),
            .init(bundleID: "com.example.notes", displayName: "Notes"),
        ])
        let target = try #require(targets.first)
        #expect(targets.count == 1)
        #expect(target.name == "ARMSX3")
        #expect(target.bundleID == "com.armsx3.ARMSX3.X53M69UJ7U")
        #expect(target.remoteRelativePath == "pairingFile.plist")
        #expect(target.app.takesRemoteRecordOnly)
    }

    @Test("ARMSX3 gets the remote pairing record alone, cut out of a merged file")
    func armsx3RecordOnly() throws {
        let merged = try plist(lockdown.merging(remote) { _, new in new })
        let record = try dictionary(try #require(ARMSX3PairingHandoff.record(from: merged)))
        #expect(Set(record.keys) == ["public_key", "private_key", "identifier", "alt_irk"])
        #expect((record["public_key"] as? Data)?.count == 32)
        #expect(record["identifier"] as? String == remote["identifier"] as? String)
    }

    @Test("ARMSX3 is handed nothing without a remote pairing record it would take")
    func armsx3Refuses() throws {
        #expect(ARMSX3PairingHandoff.record(from: try plist(lockdown)) == nil)
        var short = remote
        short["private_key"] = Data(repeating: 2, count: 31)
        #expect(ARMSX3PairingHandoff.record(from: try plist(short)) == nil)
        #expect(ARMSX3PairingHandoff.record(from: Data("not a plist".utf8)) == nil)
    }

    @Test("Madeira still takes the record alone, and the apps that read whole files don't")
    func othersUnchanged() {
        let byName = Dictionary(uniqueKeysWithValues: PairingTargetApp.all.map { ($0.name, $0) })
        #expect(byName["Madeira"]?.takesRemoteRecordOnly == true)
        #expect(byName["SideStore"]?.takesRemoteRecordOnly == false)
        #expect(byName["StikDebug"]?.takesRemoteRecordOnly == false)
    }

    @Test("Sideloaded StikDebug is handed the file it reads, Documents/pairingFile.plist")
    func sideloadedStikDebugPath() throws {
        let targets = PairingTargets.match(installed: [
            .init(bundleID: "com.stik.stikdebug.X53M69UJ7U", displayName: "StikDebug"),
        ])
        let target = try #require(targets.first)
        #expect(targets.count == 1)
        #expect(target.name == "StikDebug (Sideloaded)")
        // rp_pairing_file.plist is a leftover StikDebug deletes unread once it
        // has a pairing.
        #expect(target.remoteRelativePath == "pairingFile.plist")
    }

    @Test("The apps StikDebug places a pairing file in are listed, at their own paths")
    func stikDebugDestinations() {
        let targets = PairingTargets.match(installed: [
            .init(bundleID: "com.example.stosdebug", displayName: "StosDebug"),
            .init(bundleID: "com.example.ksign", displayName: "Ksign"),
            .init(bundleID: "com.example.autocapture", displayName: "Auto Capture"),
            .init(bundleID: "com.example.notes", displayName: "Notes"),
        ])
        let paths = Dictionary(uniqueKeysWithValues: targets.map { ($0.name, $0.remoteRelativePath) })
        #expect(paths == [
            "StosDebug": "pairingFile.plist",
            "Ksign": "pairingFile.plist",
            "Auto Capture": "rpPairingFile.plist",
        ])
        #expect(targets.allSatisfy { !$0.app.takesRemoteRecordOnly })
    }
}
