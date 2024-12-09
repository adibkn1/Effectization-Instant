import SwiftUI

@main
struct ARClip1App: App {
    var body: some Scene {
        WindowGroup {
            ARContentView()
                .edgesIgnoringSafeArea(.all)
                .statusBar(hidden: true)
        }
    }
}
