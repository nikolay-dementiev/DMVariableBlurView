import DMVariableBlurView
import UIKit
import XCTest

/// How often a blur view installs its blur again on the real system: once for each time
/// UIKit puts the standard filters back, and never otherwise. A view that installed again on
/// a pass where the blur still stood would rebuild the filter on every layout pass.
final class BlurViewReinstallationTests: XCTestCase {
    @MainActor
    func test_blurUIView_layoutPassesInASteadyState_doNotInstallAgain() {
        let sut = makeSUT()
        defer { sut.hosted.hide() }
        XCTAssertEqual(sut.installer.installCount, 1, "precondition: the first values were installed once")

        for _ in 1...2 {
            sut.view.setNeedsLayout()
            sut.hosted.window.layoutIfNeeded()
        }

        XCTAssertEqual(sut.installer.installCount, 1, "two more layout passes install nothing")
        XCTAssertGreaterThanOrEqual(sut.installer.answers.count, 2, "the passes asked whether the blur is still on")
        XCTAssertFalse(sut.installer.answers.contains(false), "every pass finds the blur where it was put")
    }

    @MainActor
    func test_blurUIView_appearanceChangesToDarkAndBack_installsOncePerChange() {
        let sut = makeSUT()
        defer { sut.hosted.hide() }

        for style in [UIUserInterfaceStyle.dark, .light] {
            let event = style == .dark ? "the change to dark" : "the change back to light"
            let installsBefore = sut.installer.installCount
            let answersBefore = sut.installer.answers.count

            sut.hosted.window.overrideUserInterfaceStyle = style
            sut.hosted.window.layoutIfNeeded()

            XCTAssertEqual(sut.installer.installCount, installsBefore + 1, "\(event) installs the blur once")
            XCTAssertEqual(
                sut.installer.answers.dropFirst(answersBefore).first,
                false,
                "\(event) makes the view learn that UIKit replaced the blur"
            )

            sut.view.setNeedsLayout()
            sut.hosted.window.layoutIfNeeded()

            XCTAssertEqual(sut.installer.installCount, installsBefore + 1, "the pass after \(event) installs nothing")
            XCTAssertEqual(sut.installer.answers.last, true, "the pass after \(event) finds the blur that was put back")
        }
    }

    @MainActor
    func test_blurUIView_effectAssignedByTheHost_installsOnce() {
        let sut = makeSUT()
        defer { sut.hosted.hide() }
        let installsBefore = sut.installer.installCount
        let answersBefore = sut.installer.answers.count

        sut.view.effect = UIBlurEffect(style: .dark)
        sut.view.layoutIfNeeded()

        XCTAssertEqual(sut.installer.installCount, installsBefore + 1, "a new effect installs the blur once")
        XCTAssertEqual(
            sut.installer.answers.dropFirst(answersBefore).first,
            false,
            "the layout pass learns that UIKit replaced the blur"
        )

        sut.view.setNeedsLayout()
        sut.view.layoutIfNeeded()

        XCTAssertEqual(sut.installer.installCount, installsBefore + 1, "the pass after the new effect installs nothing")
        XCTAssertEqual(sut.installer.answers.last, true, "the pass after the new effect finds the blur that was put back")
    }

    @MainActor
    func test_blurUIView_effectSetToNil_installsNothingWhileTheEffectIsMissing() {
        let sut = makeSUT()
        defer { sut.hosted.hide() }
        let installsBefore = sut.installer.installCount
        let answersBefore = sut.installer.answers.count

        sut.view.effect = nil
        for _ in 1...2 {
            sut.view.setNeedsLayout()
            sut.view.layoutIfNeeded()
        }

        XCTAssertEqual(sut.installer.installCount, installsBefore, "a view without an effect has no backdrop to install on")
        XCTAssertEqual(sut.installer.answers.count, answersBefore, "the view does not ask about a blur that cannot be there")
        XCTAssertNil(sut.view.failure, "no effect is not a failure")
    }

    @MainActor
    func test_blurUIView_effectRemovedAndRestored_installsOnceWhenTheEffectReturns() {
        let sut = makeSUT()
        defer { sut.hosted.hide() }
        let installsBefore = sut.installer.installCount
        let answersBefore = sut.installer.answers.count

        sut.view.effect = nil
        sut.view.layoutIfNeeded()
        sut.view.effect = UIBlurEffect(style: .regular)
        sut.view.layoutIfNeeded()

        XCTAssertEqual(sut.installer.installCount, installsBefore + 1, "the blur is installed once, when the effect returns")
        XCTAssertEqual(
            sut.installer.answers.dropFirst(answersBefore).first,
            false,
            "the first pass with the effect learns that UIKit put the standard filters back"
        )

        sut.view.setNeedsLayout()
        sut.view.layoutIfNeeded()

        XCTAssertEqual(sut.installer.installCount, installsBefore + 1, "the pass after the return installs nothing")
        XCTAssertEqual(sut.installer.answers.last, true, "the pass after the return finds the blur that was put back")
    }

    /// A filter the view did not install is no part of its blur: the view puts the variable blur
    /// over it and asks it for nothing.
    @MainActor
    func test_blurUIView_unrecognisedFilterOnTheBackdrop_installsTheVariableBlurAndReadsNoPrivateKeys() throws {
        let sut = makeSUT()
        defer { sut.hosted.hide() }
        let foreign = KeyAccessRecorder()
        let backdrop = try XCTUnwrap(sut.view.subviews.first)
        // Holds the filter the view installed, so that it is still alive when the foreign one
        // stands in its place and only its identity can tell the two apart.
        let installedFilters = backdrop.layer.filters
        backdrop.layer.filters = [foreign]
        let installsBefore = sut.installer.installCount

        withExtendedLifetime(installedFilters) {
            sut.view.setNeedsLayout()
            sut.hosted.window.layoutIfNeeded()
        }
        // Read before anything else looks at the filters: the hosting helper reads keys too.
        let keysRead = foreign.readKeys
        let keysWritten = foreign.writtenKeys

        XCTAssertEqual(keysRead, [], "no key is read from a filter the view did not install")
        XCTAssertEqual(keysWritten, [], "no key is set on a filter the view did not install")
        XCTAssertEqual(sut.installer.installCount, installsBefore + 1, "the blur is installed over the foreign filter")
        XCTAssertEqual(sut.installer.answers.last, false, "the view learned that its blur was not on the backdrop")
        XCTAssertEqual(sut.hosted.filterTypes, ["variableBlur"], "the backdrop carries the variable blur and nothing else")
    }

    // MARK: - Helpers

    private struct SUT {
        let hosted: HostedBlurView
        let view: DMVariableBlurUIView
        let installer: ForwardingInstallerSpy
    }

    /// A view in a window, with the real collaborators and a counting installer, that has
    /// installed its blur once.
    @MainActor
    private func makeSUT() -> SUT {
        let installer = ForwardingInstallerSpy()
        let view = DMVariableBlurUIView(
            maskRenderer: CoreGraphicsMaskImageRenderer(),
            installer: installer,
            failureLog: SystemFailureLog(),
            reduceTransparency: SystemReduceTransparencySetting()
        )
        let hosted = HostedBlurView(placing: view)
        // Light first, whatever the simulator is set to, so that dark is a change. The change is
        // laid out before the first values arrive: on a simulator set to dark, a blur installed
        // before it would be replaced by UIKit in the next pass and installed a second time.
        hosted.window.overrideUserInterfaceStyle = .light
        hosted.window.layoutIfNeeded()
        view.apply(VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0))
        hosted.window.layoutIfNeeded()
        return SUT(hosted: hosted, view: view, installer: installer)
    }
}
