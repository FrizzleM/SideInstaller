import ActivityKit
import Foundation

/// The Live Activity up while this iPhone pairs: where to go in Settings, then
/// the code Settings asks for, in the Dynamic Island and on the Lock Screen, so
/// the code can be read without leaving Settings.
///
/// Compiled into the app, which starts and updates it (`PairingLiveActivity`),
/// and into the widget extension, which draws it.
struct PairingActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable, Sendable {
        enum Stage: Codable, Hashable, Sendable {
            /// Advertising; Settings hasn't asked for a code yet.
            case waiting
            /// The code Settings is asking for.
            case code(String)
            /// Settings took the code.
            case paired
        }

        var stage: Stage
        /// The copy for `stage`, already in the app's language: the extension
        /// has neither the app's translations nor its language setting.
        var title: String
        var detail: String
    }
}
