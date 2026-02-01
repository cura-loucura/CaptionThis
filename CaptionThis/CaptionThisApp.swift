import SwiftUI

@main
struct CaptionThisApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 700, height: 500)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
