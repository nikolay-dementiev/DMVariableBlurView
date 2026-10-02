import DMVariableBlurView
import SwiftUI

/// The blur modes the gallery shows, one page each.
enum GalleryMode: String, CaseIterable, Identifiable {
    case top
    case bottom
    case center
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: ".blurredTopClearBottom"
        case .bottom: ".blurredBottomClearTop"
        case .center: ".blurredCenterClearTopBottom"
        case .full: ".blurredFully"
        }
    }

    var direction: DMVariableBlurDirection {
        switch self {
        case .top: .blurredTopClearBottom
        case .bottom: .blurredBottomClearTop
        case .center: .blurredCenterClearTopBottom(centerBandProportion: 0.4)
        case .full: .blurredFully
        }
    }
}

/// A paged gallery: every page shows one blur mode over the same background.
struct GalleryView: View {
    var body: some View {
        TabView {
            ForEach(GalleryMode.allCases) { mode in
                GalleryPage(mode: mode)
            }
        }
        .tabViewStyle(.page)
        .ignoresSafeArea()
    }
}

struct GalleryPage: View {
    let mode: GalleryMode

    var body: some View {
        ZStack {
            StripedBackground()

            // The blur view takes touches by default. The gallery lets them through,
            // so a swipe over the blurred area still turns the page.
            DMVariableBlurView(maxBlurRadius: 8, direction: mode.direction)
                .allowsHitTesting(false)

            Text(mode.title)
                .font(.headline)
                .padding()
                .background(.regularMaterial, in: Capsule())
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("Gallery") {
    GalleryView()
}

#Preview("Top") {
    GalleryPage(mode: .top)
}

#Preview("Bottom") {
    GalleryPage(mode: .bottom)
}

#Preview("Center band") {
    GalleryPage(mode: .center)
}

#Preview("Full") {
    GalleryPage(mode: .full)
}
