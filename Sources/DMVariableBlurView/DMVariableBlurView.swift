// Created by Mykola Dementiev
//
// for detail, pls. check the original file github page: https://github.com/nikstar/VariableBlur?tab=readme-ov-file

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import QuartzCore

public enum DMVariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
    case blurredCenterClearTopBottom(centerBandProportion: CGFloat = 0.3) // centerBandProportion: 0...1
    case blurredFully
}

public struct DMVariableBlurView: UIViewRepresentable {
    var maxBlurRadius: CGFloat = 20
    var direction: DMVariableBlurDirection = .blurredCenterClearTopBottom()
    /// By default, variable blur starts from 0 blur radius and linearly increases to `maxBlurRadius`.
    /// Setting `startOffset` to a small negative coefficient (e.g. -0.1) will start
    /// blur from larger radius value which might look better in some cases.
    var startOffset: CGFloat = 0

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
        let gradientImage = try makeGradientImage(
            startOffset: startOffset,
            direction: direction
        )
        
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
    
    private func makeGradientImage(
        width: CGFloat = 100,
        height: CGFloat = 100,
        startOffset: CGFloat,
        direction: DMVariableBlurDirection
    ) throws -> CGImage {
        let context = CIContext()
        
        switch direction {
        case .blurredTopClearBottom:
            
            return try makeBlurredTopClearBottomImage(
                width: width,
                height: height,
                startOffset: startOffset,
                context: context
            )
        case .blurredBottomClearTop:
            
            return try makeBlurredBottomClearTopImage(
                width: width,
                height: height,
                startOffset: startOffset,
                context: context
            )
        case .blurredCenterClearTopBottom(let centerBandProportion):
            
            return try makeBlurredCenterClearTopBottomImage(
                width: width,
                height: height,
                startOffset: startOffset,
                context: context,
                centerBandProportion: centerBandProportion
            )
        case .blurredFully:
            
            return try makeFullyBluredImage(
                width: width,
                height: height,
                context: context
            )
        }
    }
    
    enum VariableBlurError: Error, LocalizedError {
        case outputImageFromCIGradientFilter
        case createImageFromContext
        case findFilterFromVariableBlur
        case findVariableBlurFromFilter
        case centerBandProportionOutOfRange(currentValue: CGFloat)
        
        var errorDescription: String {
            let errorDescriptionString: String
            switch self {
            case .outputImageFromCIGradientFilter:
                errorDescriptionString = "failed to get output image from CIGradientFilter"
            case .createImageFromContext:
                errorDescriptionString = "failed to create CGImage from CIContext"
            case .findFilterFromVariableBlur:
                errorDescriptionString = "can't find CAFilter class"
            case .findVariableBlurFromFilter:
                errorDescriptionString = "CAFilter can't create filterWithType: variableBlur"
            case .centerBandProportionOutOfRange(let actual):
                errorDescriptionString = "centerBandProportion must be in range 0...1; but it is `\(actual)` instead"
            }
            
            return "[\(type(of: DMVariableBlurView.self))] Error: \(errorDescriptionString)"
        }
    }
}

private extension DMVariableBlurUIView {
    func makeBlurredTopClearBottomImage(
        width: CGFloat,
        height: CGFloat,
        startOffset: CGFloat,
        context: CIContext
    ) throws -> CGImage {
        let ciImage = try makeVerticalGradientImage(
            width: width,
            height: height,
            color0: .black,
            color1: .clear,
            y0: height,
            y1: startOffset * height,
            context: context
        )
        
        return try exportCGImage(from: ciImage, width: width, height: height, context: context)
    }
    
    func makeBlurredBottomClearTopImage(
        width: CGFloat,
        height: CGFloat,
        startOffset: CGFloat,
        context: CIContext
    ) throws -> CGImage {
        let ciImage = try makeVerticalGradientImage(
            width: width,
            height: height,
            color0: .black,
            color1: .clear,
            y0: 0,
            y1: height - startOffset * height,
            context: context
        )
        
        return try exportCGImage(from: ciImage, width: width, height: height, context: context)
    }
    
    func makeBlurredCenterClearTopBottomImage(
        width: CGFloat,
        height: CGFloat,
        startOffset: CGFloat,
        context: CIContext,
        centerBandProportion: CGFloat
    ) throws -> CGImage {
        
        guard 0...1 ~= centerBandProportion else {
            throw VariableBlurError.centerBandProportionOutOfRange(currentValue: centerBandProportion)
        }
        
        let bandThickness = max(0, min(centerBandProportion, 1.0))
        let bandHeight = height * bandThickness
        let bandStart = (height - bandHeight) / 2
        let bandEnd = bandStart + bandHeight

        let topImage = try makeVerticalGradientImage(
            width: width,
            height: height,
            color0: .clear,
            color1: .black,
            y0: 0,
            y1: bandStart,
            context: context
        )

        let bottomImage = try makeVerticalGradientImage(
            width: width,
            height: height,
            color0: .clear,
            color1: .black,
            y0: height,
            y1: bandEnd,
            context: context
        )

        // minimumCompositing = intersection for center band
        let compositeFilter = CIFilter.minimumCompositing()
        compositeFilter.inputImage = topImage
        compositeFilter.backgroundImage = bottomImage
        guard let combinedImage = compositeFilter.outputImage else {
            throw VariableBlurError.outputImageFromCIGradientFilter
        }
        
        return try exportCGImage(from: combinedImage, width: width, height: height, context: context)
    }
    
    func makeFullyBluredImage(
        width: CGFloat,
        height: CGFloat,
        context: CIContext
    ) throws -> CGImage {
        // Fully blurred: solid black mask
        let ciImage = try makeVerticalGradientImage(
            width: width,
            height: height,
            color0: .black,
            color1: .black,
            y0: 0,
            y1: height,
            context: context
        )
        
        return try exportCGImage(from: ciImage, width: width, height: height, context: context)
    }
    
    // swiftlint:disable:next function_parameter_count
    func makeVerticalGradientImage(
        width: CGFloat,
        height: CGFloat,
        color0: CIColor,
        color1: CIColor,
        y0: CGFloat,
        y1: CGFloat,
        context: CIContext
    ) throws -> CIImage {
        let gradient = CIFilter.linearGradient()
        gradient.color0 = color0
        gradient.color1 = color1
        gradient.point0 = CGPoint(x: 0, y: y0)
        gradient.point1 = CGPoint(x: 0, y: y1)
        guard let image = gradient.outputImage else {
            throw VariableBlurError.outputImageFromCIGradientFilter
        }
        
        // Crop to our mask size
        return image.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }
    
    func exportCGImage(
        from ciImage: CIImage,
        width: CGFloat,
        height: CGFloat,
        context: CIContext
    ) throws -> CGImage {
        guard let cgImage = context.createCGImage(
            ciImage,
            from: CGRect(x: 0, y: 0, width: width, height: height)
        ) else {
            throw VariableBlurError.createImageFromContext
        }
        return cgImage
    }
}
