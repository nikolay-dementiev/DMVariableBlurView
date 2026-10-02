// Created by Mykola Dementiev
//
// for detail, pls. check the original file github page: https://github.com/nikstar/VariableBlur?tab=readme-ov-file

import UIKit

/// credit https://github.com/jtrivedi/VariableBlurView
public final class DMVariableBlurUIView: UIVisualEffectView {
    private let maskRenderer: any MaskImageRenderer
    private let installer: any VariableBlurInstaller
    private let failureLog: any FailureLog

    /// The reason the view cannot show the variable blur it was asked for, or `nil` when
    /// nothing prevents it.
    ///
    /// The value changes when the view is created, when
    /// ``update(maxBlurRadius:direction:startOffset:)`` is called, and when the view applies
    /// its values again after the system rebuilt the effect, for example on a change between
    /// light and dark appearance. Each recorded reason also writes one line to the unified
    /// log, also one recorded later on such a re-application. A view made by
    /// ``DMVariableBlurView`` with ``DMVariableBlurView/onFailure(_:)`` hands the reason to
    /// that handler instead.
    public private(set) var failure: DMVariableBlurError?

    /// Receives each recorded failure in a later turn of the main actor. Without it, the
    /// failure goes to the log.
    package var failureHandler: (@MainActor (DMVariableBlurError) -> Void)?

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

    /// Creates a blur view for a UIKit hierarchy.
    ///
    /// The view always exists after this call. When the values are not valid, or the
    /// system does not offer the effect, the view shows the plain blur of the system over
    /// its whole frame and ``failure`` gives the reason.
    ///
    /// - Parameters:
    ///   - maxBlurRadius: The radius of the blur where it is strongest, in points. A finite
    ///     number, 0 or greater.
    ///   - direction: Where the blur is strongest and where it fades out.
    ///   - startOffset: Moves the point where the blur ends, as a fraction of the height.
    ///     Any finite number; from 1 on, the top and bottom modes blur nothing. It does not
    ///     shape the center band or the full blur.
    public convenience init(
        maxBlurRadius: CGFloat = 20,
        direction: DMVariableBlurDirection = .blurredCenterClearTopBottom(),
        startOffset: CGFloat = 0
    ) {
        self.init(
            maskRenderer: CoreGraphicsMaskImageRenderer(),
            installer: SystemVariableBlurInstaller(),
            failureLog: SystemFailureLog()
        )
        apply(VariableBlurConfiguration(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset))
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

    /// Replaces the values of the view and applies them.
    ///
    /// A call with the values the view already has does nothing. After the call ``failure``
    /// describes the new values.
    public func update(maxBlurRadius: CGFloat, direction: DMVariableBlurDirection, startOffset: CGFloat) {
        apply(VariableBlurConfiguration(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset))
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
        guard let failureHandler else {
            failureLog.record(error, detail: detail)
            return
        }
        // The handler runs after the current update pass, so it may change the state of the
        // host. The task holds the handler of this moment and not the view.
        Task { @MainActor in
            failureHandler(error)
        }
    }
}
