import DMVariableBlurView
import UIKit
import XCTest

/// What one update of the SwiftUI view asks of the collaborators of its UIKit view. The view is
/// hosted in a window, as in an app, and the collaborators are spies, so a test sees whether the
/// wrapper hands the handler, the option and the values over together.
final class BlurViewUpdateWiringTests: XCTestCase {
    private struct Spies {
        let renderer: MaskImageRendererSpy
        let installer = VariableBlurInstallerSpy()
        let log = FailureLogSpy()
        let reduceTransparency: ReduceTransparencySettingSpy
    }

    /// The first values were never shown, because the view followed the setting. The update that
    /// turns the option off and changes the values must install the new values only.
    @MainActor
    func test_blurView_optionAndValuesChangedInOneUpdate_installsOnlyTheNewValues() throws {
        let spies = try makeSpies(reduceTransparencyEnabled: true)
        let sut = try HostedBlurView(makeView(radius: 7, followsTheSetting: true, spies: spies))
        defer { sut.hide() }
        XCTAssertEqual(spies.installer.installations.count, 0, "precondition: the setting is on, so nothing is installed")

        _ = try sut.update(makeView(radius: 9, followsTheSetting: false, spies: spies))

        XCTAssertEqual(spies.installer.installations.map(\.maxBlurRadius), [9], "only the new values are installed")
    }

    /// The first values would be refused by the system. They were never shown, so the handler of
    /// the update that replaces them hears nothing about them.
    @MainActor
    func test_blurView_optionAndValuesChangedInOneUpdate_reportsNothingAboutTheReplacedValues() async throws {
        let spies = try makeSpies(reduceTransparencyEnabled: true)
        spies.installer.outcomeForRadius[7] = .unavailable(.notApplied)
        let sut = try HostedBlurView(makeView(radius: 7, followsTheSetting: true, spies: spies))
        defer { sut.hide() }
        var reports: [DMVariableBlurError] = []

        _ = try sut.update(
            makeView(radius: 9, followsTheSetting: false, spies: spies).onFailure { reports.append($0) }
        )
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(reports, [], "the handler hears nothing about the values that were never shown")
        XCTAssertNil(sut.blurView.failure, "the new values were taken")
    }

    // MARK: - Helpers

    @MainActor
    private func makeSpies(reduceTransparencyEnabled: Bool) throws -> Spies {
        Spies(
            renderer: MaskImageRendererSpy(result: .success(try makeMaskImage())),
            reduceTransparency: ReduceTransparencySettingSpy(isEnabled: reduceTransparencyEnabled)
        )
    }

    @MainActor
    private func makeView(radius: CGFloat, followsTheSetting: Bool, spies: Spies) -> DMVariableBlurView {
        DMVariableBlurView(maxBlurRadius: radius, direction: .blurredTopClearBottom)
            .respectsReduceTransparency(followsTheSetting)
            .collaborators {
                VariableBlurCollaborators(
                    maskRenderer: spies.renderer,
                    installer: spies.installer,
                    failureLog: spies.log,
                    reduceTransparency: spies.reduceTransparency
                )
            }
    }
}
