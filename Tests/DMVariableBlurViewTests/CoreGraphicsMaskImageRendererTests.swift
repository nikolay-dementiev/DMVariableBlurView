import DMVariableBlurView
import XCTest

/// The renderer writes every row of the mask from the profile: the alpha of the profile at
/// the center of the row, top row first.
final class CoreGraphicsMaskImageRendererTests: XCTestCase {
    /// The top mode is not symmetric, so an inverted axis or a shift by one row is visible.
    func test_render_blurredTopClearBottom_writesTheAlphaAtTheCenterOfEachRowTopRowFirst() throws {
        let rows = try alphaColumn(of: makeSUT().makeMaskImage(for: profile(.blurredTopClearBottom)))

        XCTAssertEqual(rows.count, 100, "one row per hundredth of the height")
        XCTAssertEqual(rows.first, 254, "the top row: alpha 0.995 at 0.005")
        XCTAssertEqual(rows[49], 129, "row 49: alpha 0.505 at 0.495")
        XCTAssertEqual(rows[50], 126, "row 50: alpha 0.495 at 0.505")
        XCTAssertEqual(rows.last, 1, "the bottom row: alpha 0.005 at 0.995")
    }

    func test_render_centerBandOfHalfTheHeight_writesBothRampsAndTheBand() throws {
        let rows = try alphaColumn(
            of: makeSUT().makeMaskImage(for: profile(.blurredCenterClearTopBottom(centerBandProportion: 0.5)))
        )

        XCTAssertEqual(rows.first, 5, "the top row: alpha 0.02")
        XCTAssertEqual(rows[12], 128, "row 12: alpha 0.5, rounded up")
        XCTAssertEqual(rows[24], 250, "the last row above the band: alpha 0.98")
        XCTAssertEqual(rows[25], 255, "the first row of the band")
        XCTAssertEqual(rows[74], 255, "the last row of the band")
        XCTAssertEqual(rows[75], 250, "the first row below the band: alpha 0.98")
        XCTAssertEqual(rows.last, 5, "the bottom row: alpha 0.02")
    }

    func test_render_clearAndOpaqueProfiles_writeZeroAndFullAlphaInEveryRow() throws {
        XCTAssertEqual(
            try alphaColumn(of: makeSUT().makeMaskImage(for: .clear)),
            [UInt8](repeating: 0, count: 100),
            "the clear profile"
        )
        XCTAssertEqual(
            try alphaColumn(of: makeSUT().makeMaskImage(for: BlurMaskProfile(ramps: []))),
            [UInt8](repeating: 255, count: 100),
            "a profile without ramps"
        )
    }

    /// The masks of release 1.0.0, every row. The largest difference is in the message.
    func test_render_recordedConfigurations_staysWithinOneStepOfTheMasksOfRelease100() throws {
        for recorded in RecordedMask.all {
            let rows = try alphaColumn(of: makeSUT().makeMaskImage(for: recorded.profile()))
            let largest = zip(rows, recorded.rows).map { abs(Int($0) - Int($1)) }.max() ?? .max

            // zip stops at the shorter list: a row more or less would not be compared.
            XCTAssertEqual(rows.count, recorded.rows.count, "\(recorded.name): the masks have the same number of rows")
            XCTAssertLessThanOrEqual(largest, 1, "\(recorded.name): the largest difference is \(largest)")
        }
    }

    // MARK: - Helpers

    private func makeSUT() -> CoreGraphicsMaskImageRenderer {
        CoreGraphicsMaskImageRenderer()
    }

    private func profile(_ direction: DMVariableBlurDirection) throws -> BlurMaskProfile {
        try VariableBlurConfiguration(maxBlurRadius: 20, direction: direction, startOffset: 0).maskProfile()
    }

    /// The alpha of every row of the image at its middle column, top row first.
    private func alphaColumn(of image: CGImage, file: StaticString = #filePath, line: UInt = #line) throws -> [UInt8] {
        let width = image.width
        let height = image.height
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
        XCTAssertTrue(drawn, "the image can be drawn into a bitmap", file: file, line: line)
        return (0..<height).map { pixels[($0 * width + width / 2) * 4 + 3] }
    }
}
