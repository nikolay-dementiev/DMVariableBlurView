// Created by Mykola Dementiev. Derived from VariableBlurView by jtrivedi
// (https://github.com/jtrivedi/VariableBlurView) and VariableBlur by nikstar
// (https://github.com/nikstar/VariableBlur), both under the MIT licence.

import UIKit

/// A UIKit view that blurs what lies behind it, with a blur radius that changes from row to
/// row.
///
/// Add it over the content to blur and give it a frame. Where the blur is strongest and
/// where it fades to clear is set by ``DMVariableBlurDirection``;
/// ``update(maxBlurRadius:direction:startOffset:)`` changes the values later.
///
/// - Like every view, it is used on the main thread.
/// - It receives the touches in its frame. Set `isUserInteractionEnabled` to `false` to
///   let them reach the views underneath.
/// - The views of the blur itself are no accessibility elements. Content added to its
///   `contentView` keeps its own accessibility.
/// - The blur uses a private filter of the system. When the filter is not available, or a
///   value is not valid, the view shows the plain blur of the system instead, and
///   ``failure`` gives the reason.
/// - Content added to its `contentView` stays visible over the blur.
/// - A host may set `effect` to `nil` to fade the view out. Valid values then wait for the
///   effect, and the blur shows them when the effect returns; a value that is not valid is
///   reported at once.
/// - It cannot be decoded from an archive or a storyboard: decoding returns `nil`.
public final class DMVariableBlurUIView: UIVisualEffectView {
    private let maskRenderer: any MaskImageRenderer
    private let installer: any VariableBlurInstaller
    private let failureLog: any FailureLog
    private let reduceTransparency: any ReduceTransparencySetting

    /// The reason the view cannot show the variable blur it was asked for, or `nil` when
    /// nothing prevents it.
    ///
    /// The value changes when the view is created, when
    /// ``update(maxBlurRadius:direction:startOffset:)`` is called, when the view applies its
    /// values again after the system rebuilt the effect, for example on a change between
    /// light and dark appearance, and when ``respectsReduceTransparency`` or the setting
    /// changes and the view shows its values again. Each recorded reason also writes one
    /// line to the unified log, also one recorded later on such a re-application. A view
    /// made by ``DMVariableBlurView`` with ``DMVariableBlurView/onFailure(_:)`` hands the
    /// reason to that handler instead.
    public private(set) var failure: DMVariableBlurError?

    /// Whether the view follows the Reduce Transparency setting of the device.
    ///
    /// `false` by default, as in release 1.0.0: the view ignores the setting and shows the
    /// variable blur whenever its values are valid and the system offers the effect. Set it to
    /// `true` and the view shows the standard effect of the system while the setting is on;
    /// the system then draws that effect without transparency. The view changes back when the
    /// setting is turned off. A change of this property is applied at once. Following the
    /// setting is not a failure: ``failure`` stays `nil`. A failure that is already recorded
    /// stays recorded when the option or the setting changes.
    public var respectsReduceTransparency = false {
        didSet {
            guard respectsReduceTransparency != oldValue else { return }
            settingChanged()
        }
    }

    /// Receives each recorded failure in a later turn of the main actor. Without it, the
    /// failure goes to the log.
    package var failureHandler: (@MainActor (DMVariableBlurError) -> Void)?

    /// The blur the view put on its backdrop, or will put on it once the host gives the view
    /// an effect again; kept so that it can go back on when UIKit rebuilds the effect.
    private var installedBlur: InstalledBlur?

    /// The mask of the last valid configuration, drawn once and kept while the view
    /// follows Reduce Transparency.
    private var preparedBlur: InstalledBlur?

    /// What the view was last asked to show. A request equal to it changes nothing.
    private var lastRequest: Request?

    /// The display scale last handed to the backdrop. An equal scale is not handed over again:
    /// UIKit keeps the same backdrop, with its scale, when it rebuilds the effect and when a
    /// host takes the effect away and gives it back.
    private var appliedBackdropScale: CGFloat?

    private struct InstalledBlur {
        let maxBlurRadius: CGFloat
        let mask: CGImage
    }

    /// A configuration that passed the checks, or the reason it did not. A rejected
    /// configuration is compared through its reason, which is equal to itself also for a
    /// value that is not a number.
    private enum Request: Equatable {
        case valid(VariableBlurConfiguration, BlurMaskProfile)
        case rejected(DMVariableBlurError)
    }

    /// A view that shows the plain blur of the system until a configuration is applied.
    ///
    /// The effect view is used for its backdrop, which draws filters over the views
    /// underneath in real time.
    package init(
        maskRenderer: any MaskImageRenderer,
        installer: any VariableBlurInstaller,
        failureLog: any FailureLog,
        reduceTransparency: any ReduceTransparencySetting
    ) {
        self.maskRenderer = maskRenderer
        self.installer = installer
        self.failureLog = failureLog
        self.reduceTransparency = reduceTransparency
        super.init(effect: UIBlurEffect(style: .regular))
        reduceTransparency.onChange { [weak self] in
            // With the option off the view ignores the setting, its changes included.
            guard let self, self.respectsReduceTransparency else { return }
            self.settingChanged()
        }
        // UIKit hands the view to the handler, so the handler holds no reference to it.
        registerForTraitChanges([UITraitDisplayScale.self]) { (self: Self, _: UITraitCollection) in
            self.applyBackdropScale()
        }
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
            failureLog: SystemFailureLog(),
            reduceTransparency: SystemReduceTransparencySetting()
        )
        apply(VariableBlurConfiguration(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset))
    }

    /// The view is made in code only: decoding it returns `nil`.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Shows the variable blur of a configuration.
    ///
    /// The values are checked before anything is drawn or installed. When the variable blur
    /// cannot be shown, the view shows the plain blur of the system, records the reason in
    /// ``failure`` and writes it to the log once. A configuration equal to the last one, or
    /// rejected with an equal error, the same case and value, changes nothing.
    package func apply(_ configuration: VariableBlurConfiguration) {
        let request: Request
        do throws(DMVariableBlurError) {
            request = .valid(configuration, try configuration.maskProfile())
        } catch {
            request = .rejected(error)
        }
        guard request != lastRequest else { return }
        lastRequest = request
        preparedBlur = nil

        if case .rejected(let error) = request {
            showPlainBlur()
            record(error, detail: nil)
            return
        }
        present()
    }

    /// Replaces the values of the view and applies them.
    ///
    /// A call with the values the view already has does nothing. After the call ``failure``
    /// describes the new values.
    public func update(maxBlurRadius: CGFloat, direction: DMVariableBlurDirection, startOffset: CGFloat) {
        apply(VariableBlurConfiguration(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset))
    }

    /// Lays out the effect view, then puts the variable blur back when UIKit has replaced it
    /// with the standard filters, as after a change of appearance or of `effect`.
    public override func layoutSubviews() {
        super.layoutSubviews()
        // After a change of appearance or of `effect`, UIKit puts the standard filters of
        // the effect back inside this layout pass. The variable blur goes back on in the same
        // pass, before the transaction reaches the screen. Without an effect there is no
        // backdrop: the blur waits for the effect to come back.
        guard effect != nil,
              let installedBlur,
              !installer.isInstalled(maxBlurRadius: installedBlur.maxBlurRadius, mask: installedBlur.mask, on: self)
        else { return }
        let installation = installer.install(maxBlurRadius: installedBlur.maxBlurRadius, mask: installedBlur.mask, on: self)
        if case .unavailable(let reason) = installation {
            // Trying again in every layout pass would not change the answer of the system.
            self.installedBlur = nil
            record(.effectUnavailable, detail: String(describing: reason))
            return
        }
        applyBackdropScale()
    }

    /// Gives the backdrop the display scale of the view's traits in the new window, so that
    /// the clear edge stays sharp. A view without an effect gives it once the blur is back.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        applyBackdropScale()
    }

    /// Hands the display scale of the view's traits to the backdrop: when the view enters a
    /// window, after each installation of the blur, and when the display scale changes.
    private func applyBackdropScale() {
        // Without it the clear edge looks pixelated (https://github.com/nikstar/VariableBlur/issues/1):
        // by default the backdrop renders at a fraction of the display scale. Out of a window
        // there is no display, and without an effect the backdrop is not among the subviews,
        // so the scale waits for both. When the effect returns, UIKit brings back the same
        // backdrop with the scale it had.
        guard window != nil, effect != nil else { return }
        let scale = traitCollection.displayScale
        guard scale != appliedBackdropScale else { return }
        installer.setBackdropScale(scale, on: self)
        appliedBackdropScale = scale
    }

    /// Shows the last valid configuration as the option allows: the standard effect while
    /// the view follows Reduce Transparency and the setting is on, the variable blur
    /// otherwise. The mask is drawn once per configuration.
    private func present() {
        guard case .valid(let configuration, let profile) = lastRequest else { return }
        if respectsReduceTransparency && reduceTransparency.isEnabled {
            showPlainBlur()
            failure = nil
            return
        }

        let blur: InstalledBlur
        if let preparedBlur {
            blur = preparedBlur
        } else {
            do {
                blur = InstalledBlur(
                    maxBlurRadius: configuration.maxBlurRadius,
                    mask: try maskRenderer.makeMaskImage(for: profile)
                )
            } catch {
                showPlainBlur()
                record(.maskCreationFailed, detail: String(describing: error))
                return
            }
            preparedBlur = blur
        }

        // A host that faded the view out removed the effect, and with it the backdrop. The
        // blur waits: the first layout pass after the effect returns puts it on.
        guard effect != nil else {
            installedBlur = blur
            failure = nil
            return
        }
        let installation = installer.install(maxBlurRadius: blur.maxBlurRadius, mask: blur.mask, on: self)
        if case .unavailable(let reason) = installation {
            showPlainBlur()
            record(.effectUnavailable, detail: String(describing: reason))
            return
        }
        installedBlur = blur
        failure = nil
        applyBackdropScale()
    }

    /// The option or the setting changed. A configuration that failed stays as it is:
    /// showing it again would report the same failure again.
    private func settingChanged() {
        guard case .valid = lastRequest, failure == nil else { return }
        present()
    }

    /// Brings back the standard filters and the tint of the effect, and stops putting the
    /// variable blur back in layout passes. UIKit ignores an effect equal to the current
    /// one, so the effect goes through `nil` first. An effect the host removed stays removed:
    /// the plain blur shows when the host gives the view an effect again.
    private func showPlainBlur() {
        installedBlur = nil
        guard effect != nil else { return }
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
