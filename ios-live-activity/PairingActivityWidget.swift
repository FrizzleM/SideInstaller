import ActivityKit
import SwiftUI
import WidgetKit

@main
struct SideInstallerWidgets: WidgetBundle {
    var body: some Widget {
        PairingActivityWidget()
        InstallActivityWidget()
    }
}

/// Draws `PairingActivityAttributes`: the Dynamic Island, and the card on the
/// Lock Screen, which is also the banner an iPhone without a Dynamic Island
/// drops down when the code arrives.
///
/// The code is what matters, so it's what the compact island shows once there
/// is one: it stays readable above Settings for as long as the prompt is up.
struct PairingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PairingActivityAttributes.self) { context in
            LockScreenCard(state: context.state)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Glyph(stage: state.stage, size: 36)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Destination(stage: state.stage)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        if case .code(let code) = state.stage {
                            CodeDigits(code: code, cell: CGSize(width: 42, height: 50))
                        }
                        Text(state.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                StageSymbol(stage: state.stage)
            } compactTrailing: {
                CompactTrailing(stage: state.stage)
            } minimal: {
                StageSymbol(stage: state.stage, codeReady: "ellipsis.rectangle.fill")
            }
            .keylineTint(Brand.accent)
        }
    }
}

// MARK: - Brand

/// The app's colours (`Theme`), repeated here: the extension is its own
/// binary and takes none of the app's views.
enum Brand {
    /// The light blue the app draws on the dark.
    static let accent = Color(red: 96 / 255, green: 167 / 255, blue: 253 / 255)
    /// The filled blue, behind a white symbol.
    static let blue = Color(red: 38 / 255, green: 105 / 255, blue: 237 / 255)
    static let positive = Color(red: 76 / 255, green: 195 / 255, blue: 138 / 255)
    static let warning = Color(red: 229 / 255, green: 161 / 255, blue: 64 / 255)
    static let negative = Color(red: 229 / 255, green: 72 / 255, blue: 77 / 255)

    /// The app's page, behind a Lock Screen card: a navy so deep it reads
    /// as night.
    static let backdrop = Color(red: 5 / 255, green: 11 / 255, blue: 24 / 255)
}

private typealias Stage = PairingActivityAttributes.ContentState.Stage

// MARK: - Lock Screen

private struct LockScreenCard: View {
    var state: PairingActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Glyph(stage: state.stage, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(state.detail)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if case .code(let code) = state.stage {
                CodeDigits(code: code, cell: CGSize(width: 42, height: 50))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Brand.backdrop)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Pieces

/// The code, one cell per digit. Six digits split into two threes, the way a
/// code is read off and typed in.
private struct CodeDigits: View {
    var code: String
    var cell: CGSize

    var body: some View {
        let digits = Array(code)
        HStack(spacing: 8) {
            ForEach(Array(digits.enumerated()), id: \.offset) { index, digit in
                Text(String(digit))
                    .font(.system(size: cell.height * 0.56, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: cell.width, height: cell.height)
                    .background(cellShape.fill(.white.opacity(0.06)))
                    .overlay(cellShape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    .padding(.leading, digits.count == 6 && index == 3 ? 8 : 0)
            }
        }
        // Read out as one code, digit by digit, rather than as six numbers.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(digits.map(String.init).joined(separator: " "))
    }

    private var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }
}

/// The activity's badge: the pairing lock on the blue, or a tick once
/// paired.
private struct Glyph: View {
    var stage: Stage
    var size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(stage == .paired ? Brand.positive : Brand.blue)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: stage == .paired ? "checkmark" : "lock.iphone")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// The expanded island's other corner: where this is headed. Settings while
/// pairing, back to the app once paired.
private struct Destination: View {
    var stage: Stage

    var body: some View {
        Image(systemName: stage == .paired ? "arrow.up.forward.app.fill" : "gearshape.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(stage == .paired ? AnyShapeStyle(Brand.accent)
                                              : AnyShapeStyle(.secondary))
            .frame(width: 36, height: 36)
    }
}

/// The stage as one symbol, for the compact and minimal island. `codeReady`
/// swaps the lock for a symbol that says a code is waiting, where the code
/// itself doesn't fit.
private struct StageSymbol: View {
    var stage: Stage
    var codeReady: String? = nil

    var body: some View {
        switch stage {
        case .paired:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Brand.positive)
        case .code:
            Image(systemName: codeReady ?? "lock.iphone")
                .foregroundStyle(Brand.accent)
        case .waiting:
            Image(systemName: "lock.iphone")
                .foregroundStyle(Brand.accent)
        }
    }
}

private struct CompactTrailing: View {
    var stage: Stage

    var body: some View {
        switch stage {
        case .waiting:
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
        case .code(let code):
            Text(code)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .paired:
            Image(systemName: "arrow.up.forward.app.fill")
                .foregroundStyle(Brand.accent)
        }
    }
}
