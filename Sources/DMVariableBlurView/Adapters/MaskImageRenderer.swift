import CoreGraphics
import Foundation

/// Draws the image that shapes the blur.
package protocol MaskImageRenderer {
    /// Draws a mask profile.
    ///
    /// - Returns: An image whose alpha in every row is the alpha of the profile at that
    ///   height. The first row is the top edge.
    func makeMaskImage(for profile: BlurMaskProfile) throws -> CGImage
}

/// Writes the mask row by row from the profile, without Core Image.
///
/// Each of the 100 rows takes the alpha of the profile at its center, top row first. The
/// system stretches the mask over the view, so its size only sets how fine the ramps are.
package struct CoreGraphicsMaskImageRenderer: MaskImageRenderer {
    /// The bitmap of the mask could not be turned into an image.
    enum Failure: Error {
        case imageNotCreated
    }

    private static let width = 100
    private static let height = 100

    package init() {}

    package func makeMaskImage(for profile: BlurMaskProfile) throws -> CGImage {
        let width = Self.width
        let height = Self.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let alpha = profile.alpha(at: (CGFloat(row) + 0.5) / CGFloat(height))
            let value = UInt8((min(max(alpha, 0), 1) * 255).rounded())
            // Black with this alpha, premultiplied: only the alpha byte is not zero.
            for column in 0..<width {
                pixels[(row * width + column) * 4 + 3] = value
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              )
        else {
            throw Failure.imageNotCreated
        }
        return image
    }
}
