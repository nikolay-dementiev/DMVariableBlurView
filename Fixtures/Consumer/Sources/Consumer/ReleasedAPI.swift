import SwiftUI
import DMVariableBlurView

// This target is compiled and never run or shown, so its views carry no previews.

/// Every call shape that release 1.0.0 accepts. None of them may stop compiling.
@MainActor
enum ReleasedAPI {
    static func initializerForms() -> [DMVariableBlurView] {
        [
            DMVariableBlurView(),
            DMVariableBlurView(maxBlurRadius: 7),
            DMVariableBlurView(direction: .blurredTopClearBottom),
            DMVariableBlurView(startOffset: -0.1),
            DMVariableBlurView(maxBlurRadius: 7, direction: .blurredBottomClearTop),
            DMVariableBlurView(maxBlurRadius: 7, startOffset: -0.1),
            DMVariableBlurView(direction: .blurredFully, startOffset: -0.1),
            DMVariableBlurView(
                maxBlurRadius: 7,
                direction: .blurredCenterClearTopBottom(),
                startOffset: -0.1
            )
        ]
    }

    static func directions() -> [DMVariableBlurDirection] {
        [
            .blurredTopClearBottom,
            .blurredBottomClearTop,
            .blurredCenterClearTopBottom(),
            .blurredCenterClearTopBottom(centerBandProportion: 0.2),
            .blurredFully
        ]
    }
}

/// The call the DMUnLoader package makes for its HUD background.
struct DownstreamHUDBackground: View {
    var body: some View {
        DMVariableBlurView(
            maxBlurRadius: 4,
            direction: .blurredCenterClearTopBottom(centerBandProportion: 0.4)
        )
    }
}
