//
//  DMVariableBlurView
//
//  Created by Mykola Dementiev
//

import XCTest
@testable import DMVariableBlurView
import SwiftUI

final class DMVariableBlurViewUseCaseTests: XCTestCase {
    @MainActor
    func testBlurredTopClearBottom() {
        let blurView = DMVariableBlurView(
            maxBlurRadius: 20,
            direction: .blurredTopClearBottom,
            startOffset: 0
        )

        let (hostingController, _) = createHostingController(for: blurView)
        verifyBlurViewExists(in: hostingController)
    }

    @MainActor
    func testBlurredBottomClearTop() {
        let blurView = DMVariableBlurView(
            maxBlurRadius: 20,
            direction: .blurredBottomClearTop,
            startOffset: 0
        )

        let (hostingController, _) = createHostingController(for: blurView)
        verifyBlurViewExists(in: hostingController)
    }

    @MainActor
    func testBlurredCenterClearTopBottom() {
        let blurView = DMVariableBlurView(
            maxBlurRadius: 20,
            direction: .blurredCenterClearTopBottom(centerBandProportion: 0.5),
            startOffset: 0
        )

        let (hostingController, _) = createHostingController(for: blurView)
        verifyBlurViewExists(in: hostingController)
    }

    @MainActor
    func testBlurredFully() {
        let blurView = DMVariableBlurView(
            maxBlurRadius: 20,
            direction: .blurredFully,
            startOffset: 0
        )

        let (hostingController, _) = createHostingController(for: blurView)
        verifyBlurViewExists(in: hostingController)
    }

    @MainActor
    func testStartOffsetAdjustsBlurRadius() {
        let blurView = DMVariableBlurView(
            maxBlurRadius: 20,
            direction: .blurredTopClearBottom,
            startOffset: -0.1 // Small negative offset
        )

        let (hostingController, _) = createHostingController(for: blurView)
        verifyBlurViewExists(in: hostingController)
    }

    @MainActor
    func testInvalidDirectionThrowsError() {
        let invalidCenterBandProportionValue: CGFloat = 1.5
        let invalidDirection: DMVariableBlurDirection = .blurredCenterClearTopBottom(
            centerBandProportion: invalidCenterBandProportionValue
        )

        do {
            _ = try DMVariableBlurUIView(
                maxBlurRadius: 20,
                direction: invalidDirection,
                startOffset: 0
            )
            XCTFail("Expected an error to be thrown for invalid direction")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                DMVariableBlurUIView
                    .VariableBlurError
                    .centerBandProportionOutOfRange(currentValue: invalidCenterBandProportionValue)
                    .localizedDescription
            )
        }
    }

    // MARK: - Helper Methods

    /// Creates a hosting controller for the given SwiftUI view.
    @MainActor
    private func createHostingController(for view: some View) -> (UIHostingController<some View>, UIWindow) {

        let hostingController = UIHostingController(rootView: view)
        hostingController.loadViewIfNeeded()

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = hostingController
        window.isHidden = false

        hostingController.view.layoutIfNeeded()

        return (hostingController, window)
    }

    /// Verifies that the `DMVariableBlurUIView` is properly added to the view hierarchy.
    @MainActor
    private func verifyBlurViewExists(in hostingController: UIHostingController<some View>) {
        guard let blurView = findSubview(in: hostingController.view, ofType: DMVariableBlurUIView.self) else {
            XCTFail("The DMVariableBlurUIView should be added to the view hierarchy")
            return
        }

        XCTAssertNotNil(blurView, "The DMVariableBlurUIView should exist in the view hierarchy")
    }

    @MainActor
    private func findSubview<T: UIView>(in view: UIView, ofType type: T.Type) -> T? {
        if let matchingView = view as? T {
            return matchingView
        }

        for subview in view.subviews {
            if let foundView = findSubview(in: subview, ofType: type) {
                return foundView
            }
        }

        return nil
    }
}
