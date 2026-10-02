import SwiftUI

/// A deterministic test pattern: vertical black and white stripes, two points wide.
///
/// A blurred region of it turns flat grey and a clear region keeps full contrast, so the
/// difference between neighbouring pixels tells one from the other. It is drawn in code,
/// so it is the same on every device and needs no asset.
struct StripedBackground: View {
    static let stripeWidth: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var originX: CGFloat = 0
            while originX < size.width {
                let stripe = CGRect(x: originX, y: 0, width: Self.stripeWidth, height: size.height)
                context.fill(Path(stripe), with: .color(.black))
                originX += Self.stripeWidth * 2
            }
        }
    }
}

// MARK: - Previews

#Preview {
    StripedBackground()
}
