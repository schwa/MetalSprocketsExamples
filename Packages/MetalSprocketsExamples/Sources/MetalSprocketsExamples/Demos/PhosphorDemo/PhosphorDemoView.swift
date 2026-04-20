import DemoKit
import Foundation
import PhosphorUI
import SwiftUI

/// Shader-toy style editor that compiles a user-supplied Metal snippet at
/// runtime and feeds it to a compute kernel through a `visible_function_table`.
public struct PhosphorDemoView: DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Phosphor",
            systemImage: "text.and.command.macwindow",
            description: "Live-compile Metal shader snippets (shadertoy-style)",
            longDescription: "A shadertoy-style editor: write a Metal snippet, it's compiled at runtime into a `visible_function_table` entry inside a compute kernel, and the output is ping-ponged into a display texture. Ships with a library of example snippets.",
            group: "Complex"
        )
    }

    @State private var snippet: String = Example.plasma.source
    @State private var snippetStyle: SnippetStyle = .mainImage
    @State private var showSnippet: Bool = true
    @State private var showExpandedSnippet = false
    @State private var selectedExample: Example = .plasma


    public init() {}

    public var body: some View {
        splitContent
        .onChange(of: selectedExample) { _, newValue in
            snippet = newValue.source
            snippetStyle = newValue.style
        }
    }

    @ViewBuilder
    private var splitContent: some View {
        PhosphorView(snippet: snippet, style: snippetStyle)
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing) {
                HStack {
                    Picker("Example", selection: $selectedExample) {
                        ForEach(Example.allCases, id: \.self) { example in
                            Text(example.title).tag(example)
                        }
                    }

                    Toggle("Source", isOn: $showSnippet)
                        .toggleStyle(.switch)
                }
                if showSnippet {
                    Group {
                        if showExpandedSnippet {
                            let expanded = expandSnippet(source: snippet, style: snippetStyle)
                            TextEditor(text: .constant(expanded))
                        } else {
                            MetalTextEditor(text: $snippet)
                        }
                    }
                    .monospaced()
                    .frame(minWidth: 300, maxWidth: 800)

                    HStack {
                        Picker("Snippet Style", selection: $snippetStyle) {
                            ForEach(SnippetStyle.allCases, id: \.self) { style in
                                Text(String(describing: style)).tag(style)
                            }
                        }

                        Toggle("Show Expanded Source", isOn: $showExpandedSnippet)
                    }
                }
            }
            .padding()
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding()
        }
    }
}

// MARK: - Built-in examples

extension PhosphorDemoView {
    enum Example: String, CaseIterable, Identifiable, Hashable {
        case plasma
        case fire
        case heart
        case checkerboard
        case cityscape
        case fractalKaleidoscope
        case fractalPlant
        case helloTriangle
        case hsvRaymarch
        case iterativeTrig
        case neonLamp
        case noiseFlow
        case raymarchingSphere
        case reactionDiffusion
        case terrainRiver
        case voronoiCells
        case waterRipples
        case twiglGeek

        var id: String { rawValue }

        /// Display name.
        var title: String {
            switch self {
            case .plasma: "Plasma"
            case .fire: "Fire"
            case .heart: "Heart"
            case .checkerboard: "Checkerboard"
            case .cityscape: "Cityscape"
            case .fractalKaleidoscope: "Fractal Kaleidoscope"
            case .fractalPlant: "Fractal Plant"
            case .helloTriangle: "Hello Triangle"
            case .hsvRaymarch: "HSV Raymarch"
            case .iterativeTrig: "Iterative Trig"
            case .neonLamp: "Neon Lamp"
            case .noiseFlow: "Noise Flow"
            case .raymarchingSphere: "Raymarching Sphere"
            case .reactionDiffusion: "Reaction Diffusion"
            case .terrainRiver: "Terrain River"
            case .voronoiCells: "Voronoi Cells"
            case .waterRipples: "Water Ripples"
            case .twiglGeek: "twigl Geek"
            }
        }

        /// Resource filename (without extension) in the `Examples` bundle.
        var resourceName: String {
            switch self {
            case .plasma: "Plasma"
            case .fire: "Fire"
            case .heart: "Heart"
            case .checkerboard: "Checkerboard"
            case .cityscape: "Cityscape"
            case .fractalKaleidoscope: "FractalKaleidoscope"
            case .fractalPlant: "FractalPlant"
            case .helloTriangle: "HelloTriangle"
            case .hsvRaymarch: "HSVRaymarch"
            case .iterativeTrig: "IterativeTrig"
            case .neonLamp: "NeonLamp"
            case .noiseFlow: "NoiseFlow"
            case .raymarchingSphere: "RaymarchingSphere"
            case .reactionDiffusion: "ReactionDiffusion"
            case .terrainRiver: "TerrainRiver"
            case .voronoiCells: "VoronoiCells"
            case .waterRipples: "WaterRipples"
            case .twiglGeek: "TwiglGeekBuiltin" // handled below
            }
        }

        var style: SnippetStyle {
            self == .twiglGeek ? .twiglGeek : .mainImage
        }

        var source: String {
            if self == .twiglGeek {
                return Self.defaultTwiglGeekSource
            }
            guard let url = Bundle.module.url(forResource: resourceName, withExtension: "metal.txt", subdirectory: "Examples") else {
                return "// Missing example resource: \(resourceName).metal.txt"
            }
            return (try? String(contentsOf: url, encoding: .utf8)) ?? "// Failed to load \(resourceName).metal.txt"
        }

        private static let defaultTwiglGeekSource = """
        for(float i=-fract(t/.1),j;i++<1e2;o+=(cos((j=round(i+t/.1))*j+vec4(0,1,2,3))+1.)*exp(cos(j*j/.1)/.6)*min(1e3-i/.1+9.,i)/5e4/length((FC.xy-r*.5)/r.y+.05*cos(j*j/F4+vec2(0,5))*sqrt(i)));o=tanh(o*o);
        """
    }
}
