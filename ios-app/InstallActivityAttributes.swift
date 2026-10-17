import ActivityKit
import Foundation

/// The Live Activity up while an install runs with SideInstaller in the
/// background: the step it's on and how far along it is, or what it needs from
/// the user, or why it stopped, on the Lock Screen and in the Dynamic Island.
///
/// Below iOS 26, or when iOS turns down the background task that shows the
/// progress on 26 and later, it's up for the whole run. On 26 and later it's
/// up only while the run needs the user or has stopped, next to the background
/// task's own (`InstallActivity`).
///
/// Compiled into the app, which starts and updates it (`InstallActivity`), and
/// into the widget extension, which draws it.
struct InstallActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable, Sendable {
        enum Stage: String, Codable, Hashable, Sendable {
            /// Working through the steps.
            case running
            /// Held up on something the user has to do: `title` says what.
            case waiting
            /// iOS stopped giving the app background time; the install goes on
            /// once SideInstaller is open again.
            case paused
            /// Done; the app has the trust step.
            case installed
            /// Stopped on an error: `detail` says why.
            case stopped
        }

        var stage: Stage
        /// The copy for `stage`, already in the app's language: the extension
        /// has neither the app's translations nor its language setting.
        var title: String
        var detail: String
        /// What to do about it, for the stages that need the user.
        var action: String?
        /// The SF Symbol for what the run needs, such as the key of a 2FA code;
        /// nil for the stage's own.
        var symbol: String?
        /// The Install tab's percentage, 0…1.
        var progress: Double

        /// True for the stages that are the user's turn: the activity alerts
        /// when one comes up, and shows what to do instead of the progress.
        var needsUser: Bool {
            switch stage {
            case .waiting, .paused, .stopped: true
            case .running, .installed:        false
            }
        }
    }
}
