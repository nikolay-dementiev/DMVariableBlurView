// Created by Mykola Dementiev
//
// for detail, pls. check the original file github page: https://github.com/nikstar/VariableBlur?tab=readme-ov-file

import UIKit

/// credit https://github.com/jtrivedi/VariableBlurView
public class DMVariableBlurUIView: UIVisualEffectView {
    private let installer: any VariableBlurInstaller

    /// A view that shows the plain blur of the system.
    package init(installer: any VariableBlurInstaller) {
        self.installer = installer
        super.init(effect: UIBlurEffect(style: .regular))
    }

    convenience init() {
        self.init(installer: SystemVariableBlurInstaller())
    }

    /// A view that shows the variable blur of a configuration.
    ///
    /// The effect view is used for its backdrop, which draws filters over the views
    /// underneath in real time.
    package convenience init(
        configuration: VariableBlurConfiguration,
        maskRenderer: any MaskImageRenderer,
        installer: any VariableBlurInstaller
    ) throws {
        self.init(installer: installer)

        let mask = try maskRenderer.makeMaskImage(for: configuration.maskProfile())
        let installation = installer.install(maxBlurRadius: configuration.maxBlurRadius, mask: mask, on: self)
        if case .unavailable(let reason) = installation {
            throw DMVariableBlurError(reason)
        }
    }

    convenience init(
        maxBlurRadius: CGFloat = 20,
        direction: DMVariableBlurDirection = .blurredCenterClearTopBottom(),
        startOffset: CGFloat = 0
    ) throws {
        try self.init(
            configuration: VariableBlurConfiguration(
                maxBlurRadius: maxBlurRadius,
                direction: direction,
                startOffset: startOffset
            ),
            maskRenderer: CoreImageMaskImageRenderer(),
            installer: SystemVariableBlurInstaller()
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        // fixes visible pixelization at unblurred edge (https://github.com/nikstar/VariableBlur/issues/1)
        guard let window else { return }
        installer.setBackdropScale(window.screen.scale, on: self)
    }

    /// The name release 1.0.0 gave the error type.
    typealias VariableBlurError = DMVariableBlurError
}

private extension DMVariableBlurError {
    /// The error type has one case for a missing filter class and one case for every
    /// other reason the system gives for not showing the effect.
    init(_ reason: VariableBlurInstallation.Reason) {
        switch reason {
        case .filterClassMissing:
            self = .findFilterFromVariableBlur
        case .filterFactoryMissing, .filterTypeMissing, .filterCreationFailed, .backdropMissing, .notApplied:
            self = .findVariableBlurFromFilter
        }
    }
}
