import SwiftUI

@main
struct GiroApp: App {
    init() { Account.configure() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
