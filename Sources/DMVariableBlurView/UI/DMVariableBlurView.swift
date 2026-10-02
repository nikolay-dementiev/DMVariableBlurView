import SwiftUI

public struct DMVariableBlurView: UIViewRepresentable {
    var maxBlurRadius: CGFloat
    var direction: DMVariableBlurDirection
    /// By default, variable blur starts from 0 blur radius and linearly increases to `maxBlurRadius`.
    /// Setting `startOffset` to a small negative coefficient (e.g. -0.1) will start
    /// blur from larger radius value which might look better in some cases.
    var startOffset: CGFloat

    public init(
        maxBlurRadius: CGFloat = 20,
        direction: DMVariableBlurDirection = .blurredCenterClearTopBottom(),
        startOffset: CGFloat = .zero
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
    }

    public func makeUIView(context: Context) -> DMVariableBlurUIView {
        do {
            return try DMVariableBlurUIView(
                maxBlurRadius: maxBlurRadius,
                direction: direction,
                startOffset: startOffset)
        } catch {
            return DMVariableBlurUIView()
        }
    }

    public func updateUIView(_ uiView: DMVariableBlurUIView, context: Context) {}
}
