import CoreImage.CIFilterBuiltins

/// Draws the image that shapes the blur.
package protocol MaskImageRenderer {
    /// Draws a mask profile.
    ///
    /// - Returns: An image whose alpha in every row is the alpha of the profile at that
    ///   height. The first row is the top edge.
    func makeMaskImage(for profile: BlurMaskProfile) throws -> CGImage
}

/// Draws the mask with Core Image gradients, as release 1.0.0 does.
struct CoreImageMaskImageRenderer: MaskImageRenderer {
    // The system stretches the mask over the view, so its size only sets how fine the
    // ramps are.
    private let extent = CGRect(x: 0, y: 0, width: 100, height: 100)

    func makeMaskImage(for profile: BlurMaskProfile) throws -> CGImage {
        let context = CIContext()

        // Core Image counts rows from the bottom edge, the profile counts from the top.
        let rampImages = try profile.ramps.map { ramp in
            try makeVerticalGradientImage(
                color0: CIColor(red: 0, green: 0, blue: 0, alpha: ramp.startAlpha),
                color1: CIColor(red: 0, green: 0, blue: 0, alpha: ramp.endAlpha),
                y0: extent.height * (1 - ramp.start),
                y1: extent.height * (1 - ramp.end)
            )
        }
        guard let firstImage = rampImages.first else {
            // A profile without a ramp is opaque: a gradient from black to black.
            let opaqueImage = try makeVerticalGradientImage(
                color0: .black,
                color1: .black,
                y0: 0,
                y1: extent.height
            )
            return try exportCGImage(from: opaqueImage, context: context)
        }

        // The profile is the lowest alpha of its ramps, and minimumCompositing takes it.
        let combinedImage = try rampImages.dropFirst().reduce(firstImage) { combined, rampImage in
            let compositeFilter = CIFilter.minimumCompositing()
            compositeFilter.inputImage = rampImage
            compositeFilter.backgroundImage = combined
            guard let image = compositeFilter.outputImage else {
                throw DMVariableBlurError.outputImageFromCIGradientFilter
            }
            return image
        }
        return try exportCGImage(from: combinedImage, context: context)
    }

    private func makeVerticalGradientImage(
        color0: CIColor,
        color1: CIColor,
        y0: CGFloat,
        y1: CGFloat
    ) throws -> CIImage {
        let gradient = CIFilter.linearGradient()
        gradient.color0 = color0
        gradient.color1 = color1
        gradient.point0 = CGPoint(x: 0, y: y0)
        gradient.point1 = CGPoint(x: 0, y: y1)
        guard let image = gradient.outputImage else {
            throw DMVariableBlurError.outputImageFromCIGradientFilter
        }
        return image.cropped(to: extent)
    }

    private func exportCGImage(from ciImage: CIImage, context: CIContext) throws -> CGImage {
        guard let cgImage = context.createCGImage(ciImage, from: extent) else {
            throw DMVariableBlurError.createImageFromContext
        }
        return cgImage
    }
}
