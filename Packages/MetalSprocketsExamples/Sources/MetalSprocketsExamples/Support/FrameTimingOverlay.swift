import MetalSprocketsUI
import SwiftUI

struct FrameTimingOverlay: ViewModifier {
    @State private var frameTimingStatistics: FrameTimingStatistics?

    func body(content: Content) -> some View {
        content
            .onFrameTimingChange { frameTimingStatistics = $0 }
            .overlay(alignment: .topTrailing) {
                if let frameTimingStatistics {
                    FrameTimingView(statistics: frameTimingStatistics, options: .all)
                        .padding()
                }
            }
    }
}

extension View {
    func frameTimingOverlay() -> some View {
        modifier(FrameTimingOverlay())
    }
}
