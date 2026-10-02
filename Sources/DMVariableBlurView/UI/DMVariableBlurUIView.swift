// Created by Mykola Dementiev
//
// for detail, pls. check the original file github page: https://github.com/nikstar/VariableBlur?tab=readme-ov-file

import UIKit

/// credit https://github.com/jtrivedi/VariableBlurView
public class DMVariableBlurUIView: UIVisualEffectView {
    private let maskRenderer: any MaskImageRenderer
    private let installer: any VariableBlurInstaller
    private let failureLog: any FailureLog

    /// Why the view shows the plain blur of the system, or `nil` when nothing prevents the
    /// variable blur.
    package private(set) var failure: DMVariableBlurError?

    /// A view that shows the plain blur of the system until a configuration is applied.
    ///
    /// The effect view is used for its backdrop, which draws filters over the views
    /// underneath in real time.
    package init(
        maskRenderer: any MaskImageRenderer,
        installer: any VariableBlurInstaller,
        failureLog: any FailureLog
    ) {
        self.maskRenderer = maskRenderer
        self.installer = installer
        self.failureLog = failureLog
        super.init(effect: UIBlurEffect(style: .regular))
    }

    /// A view that works with the system: Core Image draws the mask, the filter of the
    /// system blurs, and failures go to the unified log.
    convenience init() {
        self.init(
            maskRenderer: CoreImageMaskImageRenderer(),
            installer: SystemVariableBlurInstaller(),
            failureLog: SystemFailureLog()
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the variable blur of a configuration.
    ///
    /// The values are checked before anything is drawn or installed. When the variable blur
    /// cannot be shown, the view keeps the plain blur of the system, records the reason in
    /// ``failure`` and writes it to the log once.
    package func apply(_ configuration: VariableBlurConfiguration) {
        let profile: BlurMaskProfile
        do throws(DMVariableBlurError) {
            profile = try configuration.maskProfile()
        } catch {
            record(error, detail: nil)
            return
        }

        let mask: CGImage
        do {
            mask = try maskRenderer.makeMaskImage(for: profile)
        } catch {
            record(.maskCreationFailed, detail: String(describing: error))
            return
        }

        let installation = installer.install(maxBlurRadius: configuration.maxBlurRadius, mask: mask, on: self)
        if case .unavailable(let reason) = installation {
            record(.effectUnavailable, detail: String(describing: reason))
        }
    }

    public override func didMoveToWindow() {
        // fixes visible pixelization at unblurred edge (https://github.com/nikstar/VariableBlur/issues/1)
        guard let window else { return }
        installer.setBackdropScale(window.screen.scale, on: self)
    }

    private func record(_ error: DMVariableBlurError, detail: String?) {
        failure = error
        failureLog.record(error, detail: detail)
    }
}
