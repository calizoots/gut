import SwiftUI

struct UI: App {
    var body: some Scene {
        MenuBarExtra("bine", systemImage: "circle.fill") {
            MyView()
        }
        .menuBarExtraStyle(.window)
    }
}

struct MyView: View {
    var body: some View {
        Text("Hello from Menu Bar")
            .padding()
    }
}
