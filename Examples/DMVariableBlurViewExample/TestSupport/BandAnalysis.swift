import CoreGraphics

/// How sharp the rows of a picture of two-point black and white stripes are.
///
/// Shared by the app-hosted tests and the UI tests. A blurred row of stripes turns flat
/// grey; a sharp row keeps its full contrast.
enum BandAnalysis {
    /// A picture the analysis cannot measure. A test fails on it: measured as no rows, it
    /// would read as flat grey, which is what a blur looks like.
    struct UnreadableImage: Error, CustomStringConvertible {
        let width: Int
        let height: Int

        var description: String {
            "the picture cannot be measured: \(width) x \(height) pixels"
        }
    }

    /// The contrast of every pixel row, top row first: the mean absolute difference of the
    /// red channel between horizontal neighbours.
    static func rowContrast(of image: CGImage) throws -> [Double] {
        let width = image.width
        let height = image.height
        guard width > 1, height > 0 else {
            throw UnreadableImage(width: width, height: height)
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else {
            throw UnreadableImage(width: width, height: height)
        }
        return (0..<height).map { row in
            var total = 0
            for column in 0..<(width - 1) {
                let left = Int(pixels[(row * width + column) * 4])
                let right = Int(pixels[(row * width + column + 1) * 4])
                total += abs(left - right)
            }
            return Double(total) / Double(width - 1)
        }
    }

    /// The mean of the rows from `start` up to, not including, `end`; 0 for no row.
    static func mean(of rows: [Double], from start: Int, to end: Int) -> Double {
        let slice = rows[min(max(start, 0), rows.count)..<min(max(end, 0), rows.count)]
        return slice.isEmpty ? 0 : slice.reduce(0, +) / Double(slice.count)
    }

    /// The contrast of `count` equal bands of the rows from `start` to `end`, each relative
    /// to `reference`.
    static func bands(of rows: [Double], from start: Int, to end: Int, count: Int, reference: Double) -> [Double] {
        let height = Double(end - start) / Double(count)
        return (0..<count).map { band in
            let from = start + Int((Double(band) * height).rounded())
            let to = start + Int((Double(band + 1) * height).rounded())
            return reference > 0 ? mean(of: rows, from: from, to: to) / reference : 0
        }
    }
}
