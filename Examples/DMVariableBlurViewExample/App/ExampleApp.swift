import SwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            if let scene = UITestScene.requested() {
                scene.view
            } else {
                GalleryView()
            }
        }
    }
}
