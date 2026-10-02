import DMVariableBlurView

// Every declaration added after release 1.0.0, used the way a consumer would use it.

/// Directions compare as values and cross concurrency domains; failures reach the host.
@MainActor
enum AddedAPI {
    static func directionsCompare() -> Bool {
        DMVariableBlurDirection.blurredFully == .blurredFully
    }

    /// A host that keeps the reason in its state and tells the reasons apart.
    static func failureReachesTheHost(_ onReason: @escaping @MainActor (String) -> Void) -> DMVariableBlurView {
        DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: 0.4))
            .onFailure { error in
                switch error {
                case .invalidMaxBlurRadius, .invalidCenterBandProportion, .invalidStartOffset:
                    onReason("check the values: \(error.localizedDescription)")
                case .effectUnavailable, .maskCreationFailed:
                    onReason("the plain blur is shown")
                }
            }
    }

    /// A UIKit host: the defaults, explicit values, an update and the failure state.
    static func uiKitHost() -> [DMVariableBlurUIView] {
        let defaults = DMVariableBlurUIView()
        let explicit = DMVariableBlurUIView(maxBlurRadius: 12, direction: .blurredTopClearBottom, startOffset: -0.1)
        explicit.update(maxBlurRadius: 8, direction: .blurredBottomClearTop, startOffset: 0)
        if let reason = explicit.failure {
            print(reason.localizedDescription)
        }
        return [defaults, explicit]
    }

    static func directionCrossesToAnotherTask() async -> DMVariableBlurDirection {
        let direction = DMVariableBlurDirection.blurredCenterClearTopBottom(centerBandProportion: 0.4)
        return await Task.detached { direction }.value
    }
}
