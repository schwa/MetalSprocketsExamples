import AppKit
import SwiftUI

public struct ScreenshotViewModifier: ViewModifier {
    @State private var hostingView: NSView?

    public init() {
    }

    public func body(content: Content) -> some View {
        content
            .background(ViewHostingReader { view in
                hostingView = view
            })
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Screenshot") {
                        takeScreenshot()
                    }
                }
            }
    }

    @MainActor
    private func takeScreenshot() {
        print("=== SCREENSHOT ===")

        guard let view = hostingView else {
            print("No hosting view found")
            return
        }

        guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            print("Failed to create bitmap")
            return
        }

        view.cacheDisplay(in: view.bounds, to: bitmapRep)

        guard let imageData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to create PNG data")
            return
        }

        let base64 = imageData.base64EncodedString()
        print("Screenshot captured: \(bitmapRep.pixelsWide)x\(bitmapRep.pixelsHigh)")

        // iTerm2 inline image protocol
        print("\u{1b}]1337;File=inline=1:\(base64)\u{07}")
    }
}

struct ViewHostingReader: NSViewRepresentable {
    let onCapture: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window?.contentView {
                onCapture(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window?.contentView {
            onCapture(window)
        }
    }
}

public extension View {
    func screenshotButton() -> some View {
        modifier(ScreenshotViewModifier())
    }
}
