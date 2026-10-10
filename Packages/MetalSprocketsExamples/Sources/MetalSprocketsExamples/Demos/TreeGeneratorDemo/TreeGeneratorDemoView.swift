import DemoKit
import Interaction3D
import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

/// Space-colonization tree generator, ported from hugomarques13/TreeGenerator.
public struct TreeGeneratorDemoView: View {
    @State private var parameters: TreeParameters = {
        var parameters = TreeParameters()
        TreePreset.oak.apply(to: &parameters)
        return parameters
    }()
    @State private var preset: TreePreset = .oak

    @State private var vertexBuffer: MTLBuffer?
    @State private var vertexCount = 0
    @State private var statistics = ""

    @State private var cameraRotation = simd_quatf(angle: -.pi / 12, axis: [1, 0, 0])
    @State private var cameraDistance: Float = 14
    @State private var cameraTarget: SIMD3<Float> = [0, 3.5, 0]

    public init() {
        // This line intentionally left blank.
    }

    private var cameraMatrix: simd_float4x4 {
        float4x4.translation(cameraTarget.x, cameraTarget.y, cameraTarget.z) * float4x4(cameraRotation) * float4x4.translation(0, 0, cameraDistance)
    }

    public var body: some View {
        RenderView { _, drawableSize in
            let aspect = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1
            let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 500)
            try RenderPass(label: "Tree") {
                if let vertexBuffer {
                    try TreeGeneratorElement(
                        vertexBuffer: vertexBuffer,
                        vertexCount: vertexCount,
                        uniforms: TreeGeneratorUniforms(
                            viewProjection: projectionMatrix * cameraMatrix.inverse,
                            lightDirection: normalize(SIMD3<Float>(0.5, 1, 0.4)),
                            cameraPosition: SIMD3(cameraMatrix.columns.3.x, cameraMatrix.columns.3.y, cameraMatrix.columns.3.z)
                        )
                    )
                }
                GridShader(
                    projectionMatrix: projectionMatrix,
                    cameraMatrix: cameraMatrix,
                    lineWidth: [0.01, 0.01],
                    gridColor: [0.4, 0.4, 0.4, 1],
                    gridScale: [1, 1],
                    highlightedLines: [],
                    majorDivision: nil,
                    backfaceColor: [0, 0, 0, 0]
                )
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
        .metalSampleCount(4)
        .metalClearColor(.init(red: 0.55, green: 0.68, blue: 0.82, alpha: 1))
        .interactiveCamera(rotation: $cameraRotation, distance: $cameraDistance, target: $cameraTarget)
        .overlay(alignment: .bottomLeading) {
            Text(statistics)
                .font(.caption.monospacedDigit())
                .padding(6)
                .background(.thinMaterial, in: .rect(cornerRadius: 6))
                .padding()
        }
        .task(id: parameters) {
            await regenerate(parameters)
        }
        .onChange(of: preset) {
            preset.apply(to: &parameters)
        }
        .demoConfiguration {
            TreeGeneratorConfigurationView(parameters: $parameters, preset: $preset)
        }
    }

    private func regenerate(_ parameters: TreeParameters) async {
        let start = ContinuousClock.now
        let mesh = await Task.detached(priority: .userInitiated) {
            let (skeleton, leaves) = SpaceColonization.generate(parameters)
            return TreeMesh.build(skeleton: skeleton, leaves: leaves, parameters: parameters)
        }.value
        guard !Task.isCancelled else {
            return
        }
        let elapsed = ContinuousClock.now - start
        vertexBuffer = mesh.makeBuffer(device: _MTLCreateSystemDefaultDevice())
        vertexCount = mesh.vertices.count
        statistics = "\(mesh.nodeCount) nodes · \(mesh.leafCount) leaves · \(mesh.vertices.count / 3) triangles · \(elapsed.formatted(.units(allowed: [.milliseconds])))"
    }
}

private struct TreeGeneratorConfigurationView: View {
    @Binding var parameters: TreeParameters
    @Binding var preset: TreePreset

    var body: some View {
        Form {
            Section("Preset") {
                Picker("Species", selection: $preset) {
                    ForEach(TreePreset.allCases) { Text($0.rawValue).tag($0) }
                }
                LabeledContent("Seed") {
                    Text("\(parameters.seed)").monospacedDigit()
                    Button("Randomize", systemImage: "dice") {
                        parameters.seed = .random(in: 0...999_999)
                    }
                }
            }
            Section("Crown") {
                Picker("Shape", selection: $parameters.crownShape) {
                    ForEach(CrownShape.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                slider("Attraction Points", value: integerBinding(\.numPoints), in: 10...2_000, fractionLength: 0)
                slider("Crown Radius", value: $parameters.crownRadius, in: 0.5...10)
                slider("Crown Height", value: $parameters.crownHeight, in: 0.5...20)
                slider("Trunk Height", value: $parameters.trunkHeight, in: 0...1)
            }
            Section("Growth") {
                slider("Influence Radius", value: $parameters.influenceRadius, in: 0.1...10)
                slider("Kill Distance", value: $parameters.killDistance, in: 0.05...2)
                slider("Step Length", value: $parameters.stepLength, in: 0.05...1)
                slider("Branch Bend", value: $parameters.branchBend, in: 0...1)
                slider("Max Iterations", value: integerBinding(\.maxIterations), in: 10...1_000, fractionLength: 0)
                slider("Merge Threshold", value: $parameters.dedupThreshold, in: 0...0.5)
            }
            Section("Thickness") {
                slider("Trunk Radius", value: $parameters.trunkRadius, in: 0.01...1)
                slider("Branch Radius", value: $parameters.branchRadius, in: 0.001...0.5)
                slider("Tip Radius", value: $parameters.tipRadius, in: 0.001...0.5)
                slider("Base Flare", value: $parameters.baseFlare, in: 0...3)
                slider("Taper Exponent", value: $parameters.branchRadiusExponent, in: 0.1...2)
                slider("Trunk Taper Rate", value: $parameters.trunkTaper, in: 0.1...5)
            }
            Section("Foliage") {
                Toggle("Generate Foliage", isOn: $parameters.useFoliage)
                slider("Leaf Size", value: $parameters.leafSize, in: 0.01...1)
                slider("Leaves per Point", value: integerBinding(\.leavesPerNode), in: 1...12, fractionLength: 0)
                slider("Leaf Spacing", value: $parameters.leafSpacing, in: 0.05...2)
                slider("Stem Offset", value: $parameters.leafSpread, in: 0...0.5)
                slider("Foliage Depth", value: $parameters.foliageDepth, in: 0...1)
                slider("Leaf Droop", value: $parameters.leafTilt, in: 0...1)
            }
        }
        .formStyle(.grouped)
    }

    private func integerBinding(_ keyPath: WritableKeyPath<TreeParameters, Int>) -> Binding<Float> {
        Binding {
            Float(parameters[keyPath: keyPath])
        } set: { newValue in
            parameters[keyPath: keyPath] = Int(newValue.rounded())
        }
    }

    private func slider(_ title: String, value: Binding<Float>, in range: ClosedRange<Float>, fractionLength: Int = 2) -> some View {
        LabeledContent(title) {
            Slider(value: value, in: range)
                .accessibilityLabel(title)
            Text(value.wrappedValue.formatted(.number.precision(.fractionLength(fractionLength))))
                .monospacedDigit()
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
}
