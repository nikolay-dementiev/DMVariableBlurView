import CoreGraphics
import Foundation
import XCTest

/// The pixel measure the band tests and the UI tests decide with, on pictures built pixel
/// by pixel.
final class BandAnalysisTests: XCTestCase {
    func test_rowContrast_blackAndWhiteColumns_isTheFullContrastInEveryRow() throws {
        let image = try makeImage(width: 4, height: 2) { column, _ in column.isMultiple(of: 2) ? 0 : 255 }

        XCTAssertEqual(try BandAnalysis.rowContrast(of: image), [255, 255])
    }

    func test_rowContrast_flatGrey_isZeroInEveryRow() throws {
        let image = try makeImage(width: 4, height: 3) { _, _ in 128 }

        XCTAssertEqual(try BandAnalysis.rowContrast(of: image), [0, 0, 0])
    }

    /// The band tests name their bands from the top, so the first row must be the top one.
    func test_rowContrast_sharpTopRowOverFlatBottomRow_listsTheTopRowFirst() throws {
        let image = try makeImage(width: 4, height: 2) { column, row in
            row == 0 ? (column.isMultiple(of: 2) ? 0 : 255) : 128
        }

        XCTAssertEqual(try BandAnalysis.rowContrast(of: image), [255, 0])
    }

    /// One column has no neighbours to compare: measured as nothing, it would read as a blur.
    func test_rowContrast_oneColumn_throwsInsteadOfMeasuringNothing() throws {
        let image = try makeImage(width: 1, height: 2) { _, _ in 0 }

        XCTAssertThrowsError(try BandAnalysis.rowContrast(of: image))
    }

    func test_bands_twoBandsOfTwoRows_areTheirMeansRelativeToTheReference() {
        let bands = BandAnalysis.bands(of: [10, 30, 50, 70], from: 0, to: 4, count: 2, reference: 20)

        XCTAssertEqual(bands, [1, 3])
    }

    // MARK: - Helpers

    /// An opaque grey-scale picture whose pixel at `column`, `row` (row 0 at the top) has
    /// the value `value(column, row)` in every channel.
    private func makeImage(width: Int, height: Int, value: (Int, Int) -> UInt8) throws -> CGImage {
        var pixels: [UInt8] = []
        for row in 0..<height {
            for column in 0..<width {
                let level = value(column, row)
                pixels += [level, level, level, 255]
            }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        return try XCTUnwrap(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
    }
}
