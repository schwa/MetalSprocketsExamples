import Foundation

public enum SnippetStyle: Hashable, CaseIterable, Sendable {
    case raw
    case original
    case twiglGeek
    /// The snippet defines `float4 mainImage(float2 position, float2 resolution, float2 mouse, float time, float frame, texture2d<float, access::read> backbuffer)`.
    case mainImage
}

/// Parses a magic comment of the form `// phosphor:style=<name>` out of a
/// snippet's source and returns the matching ``SnippetStyle``.
///
/// The marker can appear anywhere in the source. Recognised names match the
/// case names of ``SnippetStyle`` (`raw`, `original`, `twiglGeek`, `mainImage`),
/// case-insensitive. Returns `nil` if no marker is found or the name is
/// unrecognised.
public func detectSnippetStyle(source: String) -> SnippetStyle? {
    // Look for: // phosphor:style=<name>
    let pattern = #"//\s*phosphor\s*:\s*style\s*=\s*([A-Za-z]+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return nil
    }
    let range = NSRange(source.startIndex..., in: source)
    guard let match = regex.firstMatch(in: source, range: range),
        match.numberOfRanges >= 2,
        let nameRange = Range(match.range(at: 1), in: source) else {
        return nil
    }
    let name = source[nameRange].lowercased()
    switch name {
    case "raw": return .raw
    case "original": return .original
    case "twiglgeek": return .twiglGeek
    case "mainimage": return .mainImage
    default: return nil
    }
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
