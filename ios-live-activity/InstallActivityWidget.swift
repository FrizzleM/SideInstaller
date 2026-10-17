import ActivityKit
import SwiftUI
import WidgetKit

/// Draws `InstallActivityAttributes`: an install's step and percentage in the
/// Dynamic Island and on the Lock Screen while SideInstaller is in the
/// background, or, in orange, what the install needs from the user, or, in
/// red, why it stopped.
///
/// The user's turn reads differently from progress at a glance: its own symbol
/// (the key of a 2FA code, the network of the tunnel), a mark in the compact
/// island where the percentage was, a glow and an outline on the Lock Screen
/// card, and what to do where the progress bar was.
struct InstallActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InstallActivityAttributes.self) { context in
            InstallLockScreenCard(state: context.state)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    InstallGlyph(state: state, size: 36)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if state.stage.showsProgress {
                            Percent(state: state, font: .title3)
                        } else {
                            // Where a tap goes: back to the app.
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(state.stage.tint)
                        }
                    }
                    .frame(minWidth: 36, minHeight: 36)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.title)
                        .font(.headline)
                        .foregroundStyle(state.needsUser ? AnyShapeStyle(state.stage.tint)
                                                         : AnyShapeStyle(.primary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        Text(state.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(state.needsUser ? 3 : 2)
                            .multilineTextAlignment(.center)
                        if state.stage.showsProgress {
                            Bar(state: state)
                        }
                        if let action = state.action {
                            ActionLabel(text: action, tint: state.stage.tint)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                InstallSymbol(state: state)
            } compactTrailing: {
                CompactTrailing(state: state)
            } minimal: {
                if state.stage == .running {
                    ProgressView(value: state.progress)
                        .progressViewStyle(.circular)
                        .tint(state.stage.tint)
                } else {
                    InstallSymbol(state: state)
                }
            }
            .keylineTint(state.stage.tint)
        }
    }
}

private typealias Stage = InstallActivityAttributes.ContentState.Stage
private typealias ContentState = InstallActivityAttributes.ContentState

private extension Stage {
    /// Running, or paused part way: the bar and the percentage still mean
    /// something. Held up on the user or stopped, what to do takes their place.
    var showsProgress: Bool {
        switch self {
        case .running, .paused:               true
        case .waiting, .installed, .stopped:  false
        }
    }

    var symbol: String {
        switch self {
        case .running:   "square.and.arrow.down"
        case .waiting:   "hand.tap.fill"
        case .paused:    "pause.fill"
        case .installed: "checkmark"
        case .stopped:   "exclamationmark.triangle.fill"
        }
    }

    /// Orange for the user's turn, as the Install tab's "Action needed" badge,
    /// and red for an error, as its error popup.
    var tint: Color {
        switch self {
        case .running:          Brand.accent2
        case .waiting, .paused: .orange
        case .installed:        .green
        case .stopped:          .red
        }
    }

    var fill: AnyShapeStyle {
        switch self {
        case .running:          AnyShapeStyle(Brand.gradient)
        case .waiting, .paused: AnyShapeStyle(Color.orange.gradient)
        case .installed:        AnyShapeStyle(Color.green.gradient)
        case .stopped:          AnyShapeStyle(Color.red.gradient)
        }
    }

    /// The compact island's mark where the percentage was: the user's turn,
    /// or how the install ended.
    var mark: String? {
        switch self {
        case .running, .paused: nil
        case .waiting:          "exclamationmark.circle.fill"
        case .installed:        "checkmark.circle.fill"
        case .stopped:          "xmark.circle.fill"
        }
    }
}

private extension ContentState {
    var shownSymbol: String { symbol ?? stage.symbol }
}

// MARK: - Lock Screen

private struct InstallLockScreenCard: View {
    var state: ContentState

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                InstallGlyph(state: state, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(state.detail)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(state.needsUser ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if state.stage.showsProgress {
                    Percent(state: state, font: .headline)
                }
            }
            if state.stage.showsProgress {
                Bar(state: state)
            }
            if let action = state.action {
                ActionLabel(text: action, tint: state.stage.tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Brand.backdrop(glow: state.needsUser ? state.stage.tint : Brand.accent))
        .overlay {
            // The user's turn, outlined.
            if state.needsUser {
                ContainerRelativeShape()
                    .strokeBorder(state.stage.tint.opacity(0.75), lineWidth: 2)
            }
        }
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Pieces

/// The activity's badge: what the install is on or needs, on the stage's
/// colour.
private struct InstallGlyph: View {
    var state: ContentState
    var size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(state.stage.fill)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: state.shownSymbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

private struct InstallSymbol: View {
    var state: ContentState

    var body: some View {
        Image(systemName: state.shownSymbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(state.stage == .running ? AnyShapeStyle(Brand.gradient)
                                                     : AnyShapeStyle(state.stage.tint))
    }
}

/// The percentage while the install runs; a mark in the stage's colour once
/// it's the user's turn or over.
private struct CompactTrailing: View {
    var state: ContentState

    var body: some View {
        if let mark = state.stage.mark {
            Image(systemName: mark)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(state.stage.tint)
        } else {
            Percent(state: state, font: .system(size: 15, weight: .bold, design: .rounded))
        }
    }
}

/// The Install tab's percentage.
private struct Percent: View {
    var state: ContentState
    var font: Font

    var body: some View {
        Text("\(Int(state.progress * 100))%")
            .font(font.monospacedDigit())
            .foregroundStyle(state.stage == .running ? .white : state.stage.tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

private struct Bar: View {
    var state: ContentState

    var body: some View {
        ProgressView(value: state.progress)
            .progressViewStyle(.linear)
            .tint(state.stage.tint)
    }
}

/// What to do about it, as a tinted capsule: a tap anywhere on the activity
/// opens the app.
private struct ActionLabel: View {
    var text: String
    var tint: Color

    var body: some View {
        Label(text, systemImage: "arrow.up.forward.app")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.18)))
    }
}
