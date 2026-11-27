import Foundation
import Testing
@testable import SideInstaller

/// Mobile Data Mode's rules that don't need an iPhone: what counts as mobile
/// data only, which tasks are part of what the user started, and that nothing
/// asks outside one.
@Suite("Mobile Data Mode")
@MainActor
struct MobileDataModeTests {

    @Test("Mobile data only is mobile data without Wi-Fi")
    func mobileDataOnly() {
        #expect(NetworkStatus.Links(wifi: false, mobileData: true).mobileDataOnly)
        #expect(!NetworkStatus.Links(wifi: true, mobileData: true).mobileDataOnly)
        #expect(!NetworkStatus.Links(wifi: true, mobileData: false).mobileDataOnly)
        // Airplane Mode: neither.
        #expect(!NetworkStatus.Links(wifi: false, mobileData: false).mobileDataOnly)
        #expect(NetworkStatus.Links(wifi: false, mobileData: true).summary == "Wi-Fi off, mobile data on")
    }

    @Test("An action's tasks, its nested actions and the tasks it starts share it")
    func actionsNest() async {
        let mode = MobileDataMode.shared
        #expect(MobileDataAction.current == nil)
        await mode.run(.location) {
            let outer = MobileDataAction.current
            #expect(outer?.feature == .location)
            // A step that is an action of its own elsewhere joins this one.
            await mode.run(.pairing) {
                #expect(MobileDataAction.current === outer)
            }
            // A task started inside it is part of it too.
            let inner = await Task { MobileDataAction.current }.value
            #expect(inner === outer)
            // A quiet attempt is part of nothing, even here.
            await MobileDataMode.quietly {
                #expect(MobileDataAction.current == nil)
            }
        }
        #expect(MobileDataAction.current == nil)
    }

    @Test("An action that has ended asks nothing more")
    func endedActions() async throws {
        let mode = MobileDataMode.shared
        var kept: MobileDataActionContext?
        await mode.run(.apps) { kept = MobileDataAction.current }
        let action = try #require(kept)
        #expect(action.ended)
        // Outside any action, nothing is asked whatever the network.
        #expect(try await mode.prepareNewTunnel() == false)
        try await mode.requireInternet(.signIn)
        #expect(mode.prompt == nil)
    }

    @Test("Every internet need says what comes next")
    func internetNeeds() {
        let needs: [MobileDataInternetNeed] = [.install, .signIn, .signing, .diskImageDownload, .diskImage]
        for need in needs {
            #expect(need.sentence.hasSuffix("."))
            #expect(!need.logName.isEmpty)
        }
        #expect(Set(needs.map(\.sentence)).count == needs.count)
    }
}
