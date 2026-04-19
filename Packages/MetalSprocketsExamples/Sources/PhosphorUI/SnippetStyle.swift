import Foundation

public enum SnippetStyle: Hashable, CaseIterable, Sendable {
    case raw
    case original
    case twiglGeek
    /// The snippet defines `float4 mainImage(float2 position, float2 resolution, float2 mouse, float time, float frame, texture2d<float, access::read> backbuffer)`.
    case mainImage
}

public func expandSnippet(source: String, style: SnippetStyle) -> String {
    let supportCode = loadSupportCode()

    switch style {
    case .raw:
        return """
            \(supportCode)
            \(source)
        """
    case .original:
        return """
            \(supportCode)

            #import <metal_stdlib>

            using namespace metal;

            [[stitchable]] \(source)
        """
    case .twiglGeek:
        return """
        \(supportCode)

        #import <metal_stdlib>

        using namespace metal;

        [[stitchable]] float4 snippet(float2 position, float2 resolution, float2 mouse, float time, float frame, texture2d<float, access::read> backbuffer) {
            auto r = resolution;
            auto m = mouse;
            auto t = time;
            auto f = frame;
            auto b = backbuffer;
            auto FC = position;
            float4 o = float4(0, 0, 0, 1);
            // START SNIPPET
            \(source)
            // END SNIPPET
            return o;
        }
        """
    case .mainImage:
        return """
        \(supportCode)

        #import <metal_stdlib>

        using namespace metal;

        \(source)

        [[stitchable]] float4 snippet(float2 position, float2 resolution, float2 mouse, float time, float frame, texture2d<float, access::read> backbuffer) {
            return mainImage(position, resolution, mouse, time, frame, backbuffer);
        }
        """
    }
}

private func loadSupportCode() -> String {
    guard let url = Bundle.module.url(forResource: "Support", withExtension: "h") else {
        fatalError("Missing Phosphor Support.h resource")
    }
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fatalError("Failed to load Phosphor Support.h: \(error)")
    }
}
