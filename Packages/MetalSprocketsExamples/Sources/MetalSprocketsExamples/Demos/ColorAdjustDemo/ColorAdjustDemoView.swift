import DemoKit
import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import SwiftUI

public struct ColorAdjustDemoView: View {
    enum AdjustmentFunction: String, CaseIterable {
        case multiply = "Multiply"
        case gamma = "Gamma"
        case matrix = "Matrix"
        case brightnessContrast = "Brightness/Contrast"
        case hsvAdjust = "HSV"
        case colorBalance = "Color Balance"
        case levels = "Levels"
        case temperatureTint = "Temperature/Tint"
        case threshold = "Threshold"
        case vignette = "Vignette"

        var functionName: String {
            switch self {
            case .multiply: return "multiply"
            case .gamma: return "gamma"
            case .matrix: return "matrix"
            case .brightnessContrast: return "brightnessContrast"
            case .hsvAdjust: return "hsvAdjust"
            case .colorBalance: return "colorBalance"
            case .levels: return "levels"
            case .temperatureTint: return "temperatureTint"
            case .threshold: return "threshold"
            case .vignette: return "vignette"
            }
        }
    }

    let sourceTexture: MTLTexture
    let adjustedTexture: MTLTexture
    let shaderLibrary: MetalSprockets.ShaderNamespace

    @State
    private var selectedFunction: AdjustmentFunction = .vignette

    @State
    private var multiplyValue: Float = 2.0

    @State
    private var gammaValue: Float = 2.2

    @State
    private var matrixValues = float4x4(
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]
    )

    @State
    private var brightnessContrastValues = SIMD2<Float>(0.0, 1.0) // brightness, contrast

    @State
    private var hsvValues = SIMD3<Float>(0.0, 1.0, 1.0) // hue shift (degrees), saturation multiplier, value multiplier

    @State
    private var colorBalanceValues = float3x2(
        [0.0, 0.0], // shadows R/C, highlights R/C
        [0.0, 0.0], // shadows G/M, highlights G/M
        [0.0, 0.0]  // shadows B/Y, highlights B/Y
    )

    @State
    private var levelsValues = SIMD4<Float>(0.0, 1.0, 1.0, 1.0) // input black, input white, gamma, output range

    @State
    private var temperatureTintValues = SIMD2<Float>(0.0, 0.0) // temperature, tint

    @State
    private var thresholdValues = SIMD2<Float>(0.5, 0.05) // threshold, smoothness

    @State
    private var vignetteValues = SIMD4<Float>(0.5, 0.5, 0.8, 0.4) // center x, center y, intensity, radius

    public init() {
        let device = _MTLCreateSystemDefaultDevice()

        let textureLoader = MTKTextureLoader(device: device)

        let url = Bundle.module.url(forResource: "DSC_2595", withExtension: "JPG").orFatalError("Failed to find DSC_2595.JPG resource")

        sourceTexture = (try? textureLoader.newTexture(URL: url, options: [
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite]).rawValue,
            .SRGB: false
        ])).orFatalError("Failed to load color adjust source texture")

        adjustedTexture = device.makeTexture2D(pixelFormat: .rgba8Unorm, width: sourceTexture.width, height: sourceTexture.height, label: "Adjusted Texture")
        do {
            shaderLibrary = try ShaderLibrary(bundle: .metalSprocketsExampleShaders())
                .namespaced("ColorAdjust")
        } catch {
            fatalError("Failed to create shader library: \(error)")
        }
    }

    public var body: some View {
        ZStack {
            Color.clear
            RenderView { _, _ in
                try ComputePass(label: "ColorAdjust") {
                    try colorAdjustComputePipeline
                }
                try RenderPass {
                    try TextureBillboardPipeline(specifier: .texture2D(adjustedTexture))
                }
            }
            .aspectRatio(Double(sourceTexture.width) / Double(sourceTexture.height), contentMode: .fit)
        }
        .background(.black)
        .demoConfiguration {
            config()
        }
    }

    @ElementBuilder
    var colorAdjustComputePipeline: some Element {
        get throws {
            let colorAdjustFunction = try shaderLibrary.function(named: selectedFunction.functionName, type: VisibleFunction.self)

            switch selectedFunction {
            case .multiply:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: multiplyValue, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            case .gamma:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: gammaValue, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            case .matrix:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: matrixValues, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            case .brightnessContrast:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: brightnessContrastValues, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            case .hsvAdjust:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: hsvValues, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            case .colorBalance:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: colorBalanceValues, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            case .levels:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: levelsValues, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            case .temperatureTint:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: temperatureTintValues, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            case .threshold:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: thresholdValues, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            case .vignette:
                try ColorAdjustComputePipeline(inputSpecifier: .texture2D(sourceTexture, nil), inputParameters: vignetteValues, outputTexture: adjustedTexture, colorAdjustFunction: colorAdjustFunction)
            }
        }
    }

    @ViewBuilder
    func config() -> some View {
        Form {
            VStack(alignment: .leading) {
                Picker("Function", selection: $selectedFunction) {
                    ForEach(AdjustmentFunction.allCases, id: \.self) { function in
                        Text(function.rawValue).tag(function)
                    }
                }
                .pickerStyle(.menu)

                Divider()

                switch selectedFunction {
                case .multiply:
                    LabeledContent("Multiply Factor:") {
                        HStack {
                            Slider(value: $multiplyValue, in: 0...10)
                                .accessibilityLabel("Multiply Factor")
                            Text(multiplyValue, format: .number.precision(.fractionLength(2)))
                                .frame(minWidth: 50)
                        }
                    }

                case .gamma:
                    LabeledContent("Gamma:") {
                        HStack {
                            Slider(value: $gammaValue, in: 0.1...5.0)
                                .accessibilityLabel("Gamma")
                            Text(gammaValue, format: .number.precision(.fractionLength(2)))
                                .frame(minWidth: 50)
                        }
                    }

                case .matrix:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Matrix Transform:")
                                .font(.caption)
                            Spacer()
                            Menu {
                                Button("Identity") {
                                    matrixValues = float4x4(
                                        [1.0, 0.0, 0.0, 0.0],
                                        [0.0, 1.0, 0.0, 0.0],
                                        [0.0, 0.0, 1.0, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Divider()
                                Button("Sepia") {
                                    matrixValues = float4x4(
                                        [0.393, 0.349, 0.272, 0.0],
                                        [0.769, 0.686, 0.534, 0.0],
                                        [0.189, 0.168, 0.131, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Grayscale") {
                                    matrixValues = float4x4(
                                        [0.299, 0.299, 0.299, 0.0],
                                        [0.587, 0.587, 0.587, 0.0],
                                        [0.114, 0.114, 0.114, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Invert") {
                                    matrixValues = float4x4(
                                        [-1.0, 0.0, 0.0, 1.0],
                                        [0.0, -1.0, 0.0, 1.0],
                                        [0.0, 0.0, -1.0, 1.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Divider()
                                Button("Vintage") {
                                    matrixValues = float4x4(
                                        [0.5, 0.3, 0.2, 0.0],
                                        [0.4, 0.6, 0.3, 0.0],
                                        [0.3, 0.2, 0.5, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Cold") {
                                    matrixValues = float4x4(
                                        [0.8, 0.0, 0.0, 0.0],
                                        [0.0, 0.9, 0.0, 0.0],
                                        [0.0, 0.0, 1.2, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Warm") {
                                    matrixValues = float4x4(
                                        [1.2, 0.0, 0.0, 0.0],
                                        [0.0, 1.0, 0.0, 0.0],
                                        [0.0, 0.0, 0.8, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Divider()
                                Button("High Contrast") {
                                    matrixValues = float4x4(
                                        [1.5, 0.0, 0.0, -0.25],
                                        [0.0, 1.5, 0.0, -0.25],
                                        [0.0, 0.0, 1.5, -0.25],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Low Contrast") {
                                    matrixValues = float4x4(
                                        [0.5, 0.0, 0.0, 0.25],
                                        [0.0, 0.5, 0.0, 0.25],
                                        [0.0, 0.0, 0.5, 0.25],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Polaroid") {
                                    matrixValues = float4x4(
                                        [1.438, -0.062, -0.062, 0.0],
                                        [-0.122, 1.378, -0.122, 0.0],
                                        [-0.016, -0.016, 1.483, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Divider()
                                Button("Red Channel Only") {
                                    matrixValues = float4x4(
                                        [1.0, 0.0, 0.0, 0.0],
                                        [1.0, 0.0, 0.0, 0.0],
                                        [1.0, 0.0, 0.0, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Green Channel Only") {
                                    matrixValues = float4x4(
                                        [0.0, 1.0, 0.0, 0.0],
                                        [0.0, 1.0, 0.0, 0.0],
                                        [0.0, 1.0, 0.0, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Blue Channel Only") {
                                    matrixValues = float4x4(
                                        [0.0, 0.0, 1.0, 0.0],
                                        [0.0, 0.0, 1.0, 0.0],
                                        [0.0, 0.0, 1.0, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Divider()
                                Button("Swap R↔G") {
                                    matrixValues = float4x4(
                                        [0.0, 1.0, 0.0, 0.0],
                                        [1.0, 0.0, 0.0, 0.0],
                                        [0.0, 0.0, 1.0, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Swap R↔B") {
                                    matrixValues = float4x4(
                                        [0.0, 0.0, 1.0, 0.0],
                                        [0.0, 1.0, 0.0, 0.0],
                                        [1.0, 0.0, 0.0, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                                Button("Swap G↔B") {
                                    matrixValues = float4x4(
                                        [1.0, 0.0, 0.0, 0.0],
                                        [0.0, 0.0, 1.0, 0.0],
                                        [0.0, 1.0, 0.0, 0.0],
                                        [0.0, 0.0, 0.0, 1.0]
                                    )
                                }
                            } label: {
                                Label("Presets", systemImage: "slider.horizontal.3")
                            }
                            .buttonStyle(.bordered)
                        }
                        ForEach(0..<4) { row in
                            HStack(spacing: 4) {
                                ForEach(0..<4) { col in
                                    let binding = Binding(get: { matrixValues[col][row] }, set: { matrixValues[col][row] = Float($0) })
                                    TextField("", value: binding, format: .number.precision(.fractionLength(2)))
                                        .frame(width: 60)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .accessibilityLabel("Color matrix row \(row + 1) column \(col + 1)")
                                }
                            }
                        }
                    }

                case .brightnessContrast:
                    Form {
                        LabeledContent("Brightness:") {
                            HStack {
                                Slider(value: $brightnessContrastValues.x, in: -1...1)
                                    .accessibilityLabel("Brightness")
                                Text(brightnessContrastValues.x, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Contrast:") {
                            HStack {
                                Slider(value: $brightnessContrastValues.y, in: 0...2)
                                    .accessibilityLabel("Contrast")
                                Text(brightnessContrastValues.y, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                    }

                case .hsvAdjust:
                    Form {
                        LabeledContent("Hue:") {
                            HStack {
                                Slider(value: $hsvValues.x, in: -180...180)
                                    .accessibilityLabel("Hue")
                                Text("\(hsvValues.x, format: .number.precision(.fractionLength(0)))°")
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Saturation:") {
                            HStack {
                                Slider(value: $hsvValues.y, in: 0...2)
                                    .accessibilityLabel("Saturation")
                                Text(hsvValues.y, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Value:") {
                            HStack {
                                Slider(value: $hsvValues.z, in: 0...2)
                                    .accessibilityLabel("Value")
                                Text(hsvValues.z, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                    }

                case .colorBalance:
                    Form {
                        Section("Shadows") {
                            LabeledContent("R/C:") {
                                HStack {
                                    Slider(value: $colorBalanceValues[0][0], in: -0.5...0.5)
                                        .accessibilityLabel("Shadows Red/Cyan")
                                    Text(colorBalanceValues[0][0], format: .number.precision(.fractionLength(2)))
                                        .frame(minWidth: 50)
                                }
                            }
                            LabeledContent("G/M:") {
                                HStack {
                                    Slider(value: $colorBalanceValues[1][0], in: -0.5...0.5)
                                        .accessibilityLabel("Shadows Green/Magenta")
                                    Text(colorBalanceValues[1][0], format: .number.precision(.fractionLength(2)))
                                        .frame(minWidth: 50)
                                }
                            }
                            LabeledContent("B/Y:") {
                                HStack {
                                    Slider(value: $colorBalanceValues[2][0], in: -0.5...0.5)
                                        .accessibilityLabel("Shadows Blue/Yellow")
                                    Text(colorBalanceValues[2][0], format: .number.precision(.fractionLength(2)))
                                        .frame(minWidth: 50)
                                }
                            }
                        }
                        Section("Highlights") {
                            LabeledContent("R/C:") {
                                HStack {
                                    Slider(value: $colorBalanceValues[0][1], in: -0.5...0.5)
                                        .accessibilityLabel("Highlights Red/Cyan")
                                    Text(colorBalanceValues[0][1], format: .number.precision(.fractionLength(2)))
                                        .frame(minWidth: 50)
                                }
                            }
                            LabeledContent("G/M:") {
                                HStack {
                                    Slider(value: $colorBalanceValues[1][1], in: -0.5...0.5)
                                        .accessibilityLabel("Highlights Green/Magenta")
                                    Text(colorBalanceValues[1][1], format: .number.precision(.fractionLength(2)))
                                        .frame(minWidth: 50)
                                }
                            }
                            LabeledContent("B/Y:") {
                                HStack {
                                    Slider(value: $colorBalanceValues[2][1], in: -0.5...0.5)
                                        .accessibilityLabel("Highlights Blue/Yellow")
                                    Text(colorBalanceValues[2][1], format: .number.precision(.fractionLength(2)))
                                        .frame(minWidth: 50)
                                }
                            }
                        }
                    }

                case .levels:
                    Form {
                        LabeledContent("Black Point:") {
                            HStack {
                                Slider(value: $levelsValues.x, in: 0...1)
                                    .accessibilityLabel("Black Point")
                                Text(levelsValues.x, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("White Point:") {
                            HStack {
                                Slider(value: $levelsValues.y, in: 0...1)
                                    .accessibilityLabel("White Point")
                                Text(levelsValues.y, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Gamma:") {
                            HStack {
                                Slider(value: $levelsValues.z, in: 0.1...10)
                                    .accessibilityLabel("Gamma")
                                Text(levelsValues.z, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Output Range:") {
                            HStack {
                                Slider(value: $levelsValues.w, in: 0...1)
                                    .accessibilityLabel("Output Range")
                                Text(levelsValues.w, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                    }

                case .temperatureTint:
                    Form {
                        LabeledContent("Temperature:") {
                            HStack {
                                Slider(value: $temperatureTintValues.x, in: -1...1)
                                    .accessibilityLabel("Temperature")
                                Text(temperatureTintValues.x, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Tint:") {
                            HStack {
                                Slider(value: $temperatureTintValues.y, in: -1...1)
                                    .accessibilityLabel("Tint")
                                Text(temperatureTintValues.y, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                    }

                case .threshold:
                    Form {
                        LabeledContent("Threshold:") {
                            HStack {
                                Slider(value: $thresholdValues.x, in: 0...1)
                                    .accessibilityLabel("Threshold")
                                Text(thresholdValues.x, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Smoothness:") {
                            HStack {
                                Slider(value: $thresholdValues.y, in: 0...0.5)
                                    .accessibilityLabel("Smoothness")
                                Text(thresholdValues.y, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                    }

                case .vignette:
                    Form {
                        LabeledContent("Center X:") {
                            HStack {
                                Slider(value: $vignetteValues.x, in: 0...1)
                                    .accessibilityLabel("Center X")
                                Text(vignetteValues.x, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Center Y:") {
                            HStack {
                                Slider(value: $vignetteValues.y, in: 0...1)
                                    .accessibilityLabel("Center Y")
                                Text(vignetteValues.y, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Intensity:") {
                            HStack {
                                Slider(value: $vignetteValues.z, in: 0...1)
                                    .accessibilityLabel("Intensity")
                                Text(vignetteValues.z, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                        LabeledContent("Radius:") {
                            HStack {
                                Slider(value: $vignetteValues.w, in: 0.1...2)
                                    .accessibilityLabel("Radius")
                                Text(vignetteValues.w, format: .number.precision(.fractionLength(2)))
                                    .frame(minWidth: 50)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 350)
            .fixedSize(horizontal: true, vertical: false)
        }
        .formStyle(.grouped)
    }
}
