#if canImport(AppKit)
import MetalSprockets
import SwiftUI

public struct OffscreenDemoView: View {
    @State
    private var result: Result<CGImage, Error>?

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        ZStack {
            Color.clear
            if case let .success(image) = result {
                Image(nsImage: NSImage(cgImage: image, size: .zero))
                    .resizable()
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(.black)
        .demoConfiguration {
            Group {
                if case let .success(image) = result {
                    Text("\(image.width) × \(image.height)")
                }
                if case let .failure(error) = result {
                    Text(verbatim: "Failure: \(String(describing: error))")
                }
            }
        }
        .task {
            do {
                let root = RedTriangle()

                let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 1_600, height: 1_200))
                result = .success(try offscreenRenderer.render(root).cgImage)
            }
            catch {
                result = .failure(error)
            }
        }
    }
}

#endif
