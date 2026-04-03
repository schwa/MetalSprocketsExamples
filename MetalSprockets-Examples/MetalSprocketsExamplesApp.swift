import DemoKit
import MetalSprocketsExamples
import SwiftUI

private let urlScheme = "metalsprockets-examples"

@main
struct MetalSprocketsExamplesApp: App {
    var body: some Scene {
        #if os(macOS)
        Window("MetalSprockets", id: "main") {
            ContentView()
        }
        .handleDemoURL(scheme: urlScheme)
        .commands {
            DemosCommandMenu()
        }
        #else
        WindowGroup("MetalSprockets", id: "main") {
            ContentView()
        }
        .handleDemoURL(scheme: urlScheme)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

