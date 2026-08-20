import SwiftUI

@main
struct FaxinaApp: App {
    var body: some Scene {
        Window("Faxina", id: "main") {
            RootView()
        }
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
