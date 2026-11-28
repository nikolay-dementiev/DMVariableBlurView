package import DMCore

/// The five collaborators of a blur view.
///
/// The system ones are listed here and nowhere else: the public initializers of the UIKit view
/// and the SwiftUI wrapper take them from ``system``, so the object graph of the library has
/// one home.
package struct VariableBlurCollaborators {
    package let maskRenderer: any MaskImageRenderer
    package let installer: any VariableBlurInstaller
    package let failureLog: any FailureLog
    package let reduceTransparency: any ReduceTransparencySetting
    package let tracing: any Tracing

    package init(
        maskRenderer: any MaskImageRenderer,
        installer: any VariableBlurInstaller,
        failureLog: any FailureLog,
        reduceTransparency: any ReduceTransparencySetting,
        tracing: any Tracing
    ) {
        self.maskRenderer = maskRenderer
        self.installer = installer
        self.failureLog = failureLog
        self.reduceTransparency = reduceTransparency
        self.tracing = tracing
    }

    /// What a view uses on a device: the renderer that draws with CoreGraphics, the installer
    /// that talks to the system, the unified log, the Reduce Transparency setting of the
    /// device, and the signposts of the system.
    ///
    /// Each read creates new collaborators, because every view owns its own: the installer
    /// remembers the filters it put on the effect views it served, and the setting registers an
    /// observer.
    @MainActor
    package static var system: VariableBlurCollaborators {
        VariableBlurCollaborators(
            maskRenderer: CoreGraphicsMaskImageRenderer(),
            installer: SystemVariableBlurInstaller(),
            failureLog: SystemFailureLog(),
            reduceTransparency: SystemReduceTransparencySetting(),
            tracing: SystemTracing(subsystem: "DMVariableBlurView", category: "blur")
        )
    }
}
