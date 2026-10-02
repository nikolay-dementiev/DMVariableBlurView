import DMVariableBlurView

// Every declaration added after release 1.0.0, used the way a consumer would use it.

/// Directions compare as values and cross concurrency domains.
enum AddedAPI {
    static func directionsCompare() -> Bool {
        DMVariableBlurDirection.blurredFully == .blurredFully
    }

    static func directionCrossesToAnotherTask() async -> DMVariableBlurDirection {
        let direction = DMVariableBlurDirection.blurredCenterClearTopBottom(centerBandProportion: 0.4)
        return await Task.detached { direction }.value
    }
}
