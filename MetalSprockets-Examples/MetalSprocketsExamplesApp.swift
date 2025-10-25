import MetalSprocketsSnapshotUI
import SwiftUI

@main
struct MetalSprocketsExamplesApp: App {
    var body: some Scene {
        #if os(macOS)
        Window("MetalSprockets", id: "main") {
            ContentView()
        }
        #else
        WindowGroup("MetalSprockets", id: "main") {
            ContentView()
        }
        #endif

        SnapshotViewerDocumentScene()

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
