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
            DemosMenuCommands()
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

#if os(macOS)
struct DemosMenuCommands: Commands {
    @Environment(\.openURL)
    private var openURL

    private var demoMetadata: [DemoMetadata] {
        // swiftlint:disable:next prefer_key_path
        allDemos.map { $0.metadata }
    }

    var body: some Commands {
        CommandMenu("Demos") {
            ForEach(demoMetadata) { metadata in
                Button(metadata.name) {
                    guard let url = URL(string: "\(urlScheme)://\(metadata.id.rawValue)") else {
                        return
                    }
                    openURL(url)
                }
            }
        }
    }
}
#endif
