import SwiftUI

public struct DMVariableBlurView: UIViewRepresentable {
    var maxBlurRadius: CGFloat
    var direction: DMVariableBlurDirection
    /// By default, variable blur starts from 0 blur radius and linearly increases to `maxBlurRadius`.
    /// Setting `startOffset` to a small negative coefficient (e.g. -0.1) will start
    /// blur from larger radius value which might look better in some cases.
    var startOffset: CGFloat
    private var failureHandler: (@MainActor (DMVariableBlurError) -> Void)?
    private var followsReduceTransparency = false

    public init(
        maxBlurRadius: CGFloat = 20,
        direction: DMVariableBlurDirection = .blurredCenterClearTopBottom(),
        startOffset: CGFloat = .zero
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
    }

    /// Sets a handler that is told when the view cannot show the blur it was asked for.
    ///
    /// The handler runs on the main actor. It is called once for each configuration that
    /// was applied and failed. It is not called again while the configuration stays the
    /// same, however often SwiftUI updates the view; a configuration rejected for the same
    /// reason as the one before counts as the same. It is called again when a failing
    /// configuration returns after a valid one, and when a configuration that was shown
    /// fails later, for example when the view applies it again after the system rebuilt
    /// the effect.
    ///
    /// The handler is called after the update pass that applied the configuration, never
    /// from inside `makeUIView` or `updateUIView`, so it may change state. The handler that
    /// was set when the failure happened receives it, even if the view is gone by then.
    ///
    /// Without a handler the view writes one line per failure to the unified log, under the
    /// subsystem `DMVariableBlurView`.
    ///
    /// - Parameter handler: Called with the reason. A handler set by a later update
    ///   replaces the earlier one for the failures that follow.
    /// - Returns: A blur view that reports its failures to `handler`.
    public func onFailure(_ handler: @escaping @MainActor (DMVariableBlurError) -> Void) -> DMVariableBlurView {
        var view = self
        view.failureHandler = handler
        return view
    }

    /// Sets whether the view follows the Reduce Transparency setting of the device.
    ///
    /// By default the view ignores the setting and always shows the variable blur, as
    /// release 1.0.0 does. A view that follows the setting shows the standard effect of the
    /// system while the setting is on: the system then draws that effect without
    /// transparency. The view changes back when the setting is turned off.
    ///
    /// Following the setting is not a failure: nothing is reported.
    ///
    /// - Parameter respects: `true` to follow the setting. The default is `true`.
    /// - Returns: A blur view that follows the setting or ignores it.
    public func respectsReduceTransparency(_ respects: Bool = true) -> DMVariableBlurView {
        var view = self
        view.followsReduceTransparency = respects
        return view
    }

    public func makeUIView(context: Context) -> DMVariableBlurUIView {
        // The handler must be in place before the first configuration is applied.
        let view = DMVariableBlurUIView(
            maskRenderer: CoreGraphicsMaskImageRenderer(),
            installer: SystemVariableBlurInstaller(),
            failureLog: SystemFailureLog(),
            reduceTransparency: SystemReduceTransparencySetting()
        )
        view.failureHandler = failureHandler
        view.respectsReduceTransparency = followsReduceTransparency
        view.apply(configuration)
        return view
    }

    public func updateUIView(_ uiView: DMVariableBlurUIView, context: Context) {
        uiView.failureHandler = failureHandler
        uiView.respectsReduceTransparency = followsReduceTransparency
        uiView.apply(configuration)
    }

    private var configuration: VariableBlurConfiguration {
        VariableBlurConfiguration(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }
}
