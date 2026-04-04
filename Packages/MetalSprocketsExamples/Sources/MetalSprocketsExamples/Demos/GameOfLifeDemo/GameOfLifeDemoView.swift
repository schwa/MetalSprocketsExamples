import DemoKit
import MetalSprocketsUI
import SwiftUI

public struct GameOfLifeDemoView: View {
    @State private var isRunning = true
    @State private var pattern: GameOfLife.InitialPattern = .random

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        // Render view
        RenderView { _, _ in
            GameOfLife(isRunning: isRunning, pattern: pattern)
        }

        .demoConfiguration {
            Form {
                Toggle("Animate", isOn: $isRunning)

                Menu("Fill Pattern") {
                    Button("Glider") {
                        pattern = .glider
                    }
                    Button("Random") {
                        pattern = .random
                    }
                    Button("Clear") {
                        pattern = .clear
                    }
                }
            }
            .fixedSize()
        }
    }
}
