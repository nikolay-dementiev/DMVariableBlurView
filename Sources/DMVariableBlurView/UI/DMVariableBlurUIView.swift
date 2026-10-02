// Created by Mykola Dementiev
//
// for detail, pls. check the original file github page: https://github.com/nikstar/VariableBlur?tab=readme-ov-file

import UIKit

/// credit https://github.com/jtrivedi/VariableBlurView
public final class DMVariableBlurUIView: UIVisualEffectView {
    private let maskRenderer: any MaskImageRenderer
    private let installer: any VariableBlurInstaller
    private let failureLog: any FailureLog

    /// Why the view shows the plain blur of the system, or `nil` when nothing prevents the
    /// variable blur.
    package private(set) var failure: DMVariableBlurError?

    /// The blur the view put on its backdrop, kept so that it can go back on when UIKit
    /// rebuilds the effect.
    private var installedBlur: InstalledBlur?

    /// What the view was last asked to show. A request equal to it changes nothing.
    private var lastRequest: Request?

    private struct InstalledBlur {
        let maxBlurRadius: CGFloat
        let mask: CGImage
    }

    /// A configuration that passed the checks, or the reason it did not. A rejected
    /// configuration is compared through its reason, which is equal to itself also for a
    /// value that is not a number.
    private enum Request: Equatable {
        case valid(VariableBlurConfiguration)
        case rejected(DMVariableBlurError)
    }

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

    /// A view that works with the system: CoreGraphics draws the mask, the filter of the
    /// system blurs, and failures go to the unified log.
    convenience init() {
        self.init(
            maskRenderer: CoreGraphicsMaskImageRenderer(),
            installer: SystemVariableBlurInstaller(),
            failureLog: SystemFailureLog()
        )
    }

    /// The view is made in code only. Decoding it, from an archive or a storyboard,
    /// returns `nil` and leaves the host running.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Shows the variable blur of a configuration.
    ///
    /// The values are checked before anything is drawn or installed. When the variable blur
    /// cannot be shown, the view shows the plain blur of the system, records the reason in
    /// ``failure`` and writes it to the log once. A configuration equal to the last one, or
    /// rejected for the same reason, changes nothing.
    package func apply(_ configuration: VariableBlurConfiguration) {
        let profile: BlurMaskProfile
        do throws(DMVariableBlurError) {
            profile = try configuration.maskProfile()
        } catch {
            guard lastRequest != .rejected(error) else { return }
            lastRequest = .rejected(error)
            showPlainBlur()
            record(error, detail: nil)
            return
        }
        guard lastRequest != .valid(configuration) else { return }
        lastRequest = .valid(configuration)

        let mask: CGImage
        do {
            mask = try maskRenderer.makeMaskImage(for: profile)
        } catch {
            showPlainBlur()
            record(.maskCreationFailed, detail: String(describing: error))
            return
        }

        let installation = installer.install(maxBlurRadius: configuration.maxBlurRadius, mask: mask, on: self)
        if case .unavailable(let reason) = installation {
            showPlainBlur()
            record(.effectUnavailable, detail: String(describing: reason))
            return
        }
        installedBlur = InstalledBlur(maxBlurRadius: configuration.maxBlurRadius, mask: mask)
        failure = nil
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // After a change of appearance or of `effect`, UIKit puts the standard filters of
        // the effect back inside this layout pass. The variable blur goes back on in the same
        // pass, before the transaction reaches the screen.
        guard let installedBlur,
              !installer.isInstalled(maxBlurRadius: installedBlur.maxBlurRadius, mask: installedBlur.mask, on: self)
        else { return }
        let installation = installer.install(maxBlurRadius: installedBlur.maxBlurRadius, mask: installedBlur.mask, on: self)
        if case .unavailable(let reason) = installation {
            // Trying again in every layout pass would not change the answer of the system.
            self.installedBlur = nil
            record(.effectUnavailable, detail: String(describing: reason))
        }
    }

    public override func didMoveToWindow() {
        // fixes visible pixelization at unblurred edge (https://github.com/nikstar/VariableBlur/issues/1)
        guard let window else { return }
        installer.setBackdropScale(window.screen.scale, on: self)
    }

    /// Brings back the standard filters and the tint of the effect, and stops putting the
    /// variable blur back in layout passes. UIKit ignores an effect equal to the current
    /// one, so the effect goes through `nil` first.
    private func showPlainBlur() {
        installedBlur = nil
        effect = nil
        effect = UIBlurEffect(style: .regular)
    }

    private func record(_ error: DMVariableBlurError, detail: String?) {
        failure = error
        failureLog.record(error, detail: detail)
    }
}
