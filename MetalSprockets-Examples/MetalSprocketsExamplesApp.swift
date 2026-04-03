import DemoKit
import MetalSprocketsExamples
import SwiftUI

private let urlScheme = "metalsprockets-examples"

@main
struct MetalSprocketsExamplesApp: App {
    var body: some Scene {
        #if os(macOS)
        DemoPickerScene(demos: allDemos)
            .handleDemoURL(scheme: urlScheme)
            .commands {
                DemosCommandMenu()
            }
        #else
        DemoPickerScene(demos: allDemos)
            .handleDemoURL(scheme: urlScheme)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
