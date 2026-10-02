// Created by Mykola Dementiev
//
// for detail, pls. check the original file github page: https://github.com/nikstar/VariableBlur?tab=readme-ov-file

import UIKit

/// credit https://github.com/jtrivedi/VariableBlurView
public class DMVariableBlurUIView: UIVisualEffectView {

    init() {
        super.init(effect: UIBlurEffect(style: .regular))
    }

    convenience init(
        maxBlurRadius: CGFloat = 20,
        direction: DMVariableBlurDirection = .blurredCenterClearTopBottom(),
        startOffset: CGFloat = 0
    ) throws {
        self.init()

        // `CAFilter` is a private QuartzCore class that dynamically create using Objective-C runtime.
        guard let CAFilter = NSClassFromString("CAFilter") as? NSObject.Type else {
            throw VariableBlurError.findFilterFromVariableBlur
        }
        guard let variableBlur = CAFilter.self.perform(
            NSSelectorFromString("filterWithType:"),
            with: "variableBlur"
        ).takeUnretainedValue() as? NSObject else {
            throw VariableBlurError.findVariableBlurFromFilter
        }

        // The blur radius at each pixel depends on the alpha value of the corresponding pixel in the gradient mask.
        // An alpha of 1 results in the max blur radius, while an alpha of 0 is completely unblurred.
        let configuration = VariableBlurConfiguration(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
        let gradientImage = try CoreImageMaskImageRenderer().makeMaskImage(for: configuration.maskProfile())

        variableBlur.setValue(maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImage, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")

        // We use a `UIVisualEffectView` here purely to get access to its `CABackdropLayer`,
        // which is able to apply various, real-time CAFilters onto the views underneath.
        let backdropLayer = subviews.first?.layer

        // Replace the standard filters (i.e. `gaussianBlur`, `colorSaturate`, etc.) with only the variableBlur.
        backdropLayer?.filters = [variableBlur]

        // Get rid of the visual effect view's dimming/tint view, so we don't see a hard line.
        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        // fixes visible pixelization at unblurred edge (https://github.com/nikstar/VariableBlur/issues/1)
        guard let window, let backdropLayer = subviews.first?.layer else { return }
        backdropLayer.setValue(window.screen.scale, forKey: "scale")
    }

    /// The name release 1.0.0 gave the error type.
    typealias VariableBlurError = DMVariableBlurError
}
