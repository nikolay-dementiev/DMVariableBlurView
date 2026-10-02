import SwiftUI

/// A view that blurs what lies behind it, with a blur radius that changes from row to row.
///
/// Place it over the content to blur, for example in a `ZStack` or an `overlay`. Where
/// the blur is strongest and where it fades to clear is set by ``DMVariableBlurDirection``.
///
/// - The view takes the touches in its frame, as SwiftUI does for a view that wraps a
///   UIKit view. Add `.allowsHitTesting(false)` to let them reach the views underneath.
/// - No view of the blur is an accessibility element.
/// - The blur uses a private filter of the system. When the filter is not available, or a
///   value is not valid, the view shows the plain blur of the system instead and reports
///   the reason: see ``onFailure(_:)``.
public struct DMVariableBlurView: UIViewRepresentable {
    var maxBlurRadius: CGFloat
    var direction: DMVariableBlurDirection
    var startOffset: CGFloat
    private var failureHandler: (@MainActor (DMVariableBlurError) -> Void)?
    private var followsReduceTransparency = false

    /// Creates a blur view.
    ///
    /// - Parameters:
    ///   - maxBlurRadius: The blur radius where the blur is strongest, in points: a finite
    ///     number, 0 or greater. Another value is rejected with
    ///     ``DMVariableBlurError/invalidMaxBlurRadius(_:)``.
    ///   - direction: Where the view blurs and where it fades to clear. The default is a
    ///     blurred band of 30 % of the height in the middle, clear at the top and bottom.
    ///   - startOffset: Where the fade of the top and bottom modes ends, as a share of the
    ///     height. With 0 the fade spans the whole height. A positive value leaves that
    ///     share clear at the clear edge, and from 1 on nothing is blurred. A negative value
    ///     keeps some blur at the clear edge. The center band and the full blur ignore it.
    ///     A value that is not finite is rejected with
    ///     ``DMVariableBlurError/invalidStartOffset(_:)``.
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

    /// Creates the UIKit view that draws the blur. SwiftUI calls this method.
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

    /// Applies the values of this view to the UIKit view. SwiftUI calls this method when
    /// the values change; values equal to the applied ones change nothing.
    public func updateUIView(_ uiView: DMVariableBlurUIView, context: Context) {
        uiView.failureHandler = failureHandler
        uiView.respectsReduceTransparency = followsReduceTransparency
        uiView.apply(configuration)
    }

    private var configuration: VariableBlurConfiguration {
        VariableBlurConfiguration(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }
}

// The previews stay out of the release build that ships in an app.
#if DEBUG

// MARK: - Previews

#Preview("Blurred top, clear bottom") {
    BlurPreview(direction: .blurredTopClearBottom)
}

#Preview("Blurred bottom, clear top") {
    BlurPreview(direction: .blurredBottomClearTop)
}

#Preview("Blurred center band") {
    BlurPreview(direction: .blurredCenterClearTopBottom(centerBandProportion: 0.4))
}

#Preview("Blurred fully") {
    BlurPreview(direction: .blurredFully)
}

#Preview("Rejected value: the plain blur of the system") {
    BlurPreview(direction: .blurredTopClearBottom, maxBlurRadius: -1)
}

/// Labelled stripes under a blur, so that the course of the blur shows in the canvas.
private struct BlurPreview: View {
    let direction: DMVariableBlurDirection
    var maxBlurRadius: CGFloat = 20

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(1...12, id: \.self) { row in
                    Text(verbatim: "Row \(row)")
                        .font(.title2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(row.isMultiple(of: 2) ? Color.orange : Color.teal)
                }
            }
            DMVariableBlurView(maxBlurRadius: maxBlurRadius, direction: direction)
        }
        .ignoresSafeArea()
    }
}

#endif
