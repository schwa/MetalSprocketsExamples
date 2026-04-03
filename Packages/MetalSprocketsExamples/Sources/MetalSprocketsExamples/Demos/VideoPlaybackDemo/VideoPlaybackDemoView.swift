import AVFoundation
import DemoKit
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import MetalSprocketsUI
import SwiftUI

public struct VideoPlaybackDemoView: View {
    @State
    private var device = _MTLCreateSystemDefaultDevice()

    @State
    private var videoPlayer = VideoTexturePipeline(device: _MTLCreateSystemDefaultDevice())

    @State
    private var isPlaying = false

    @State
    private var videoURL: URL? = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")

    @State
    private var errorMessage: String?

    @State
    private var enableVCR = true

    @State
    private var vcrParameters = VCRParameters()

    @State
    private var distortedTexture: MTLTexture?

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        ZStack {
            RenderView { context, _ in
                if let videoTexture = videoPlayer.currentTexture {
                    if enableVCR, let distortedTexture = getOrCreateDistortedTexture(for: videoTexture) {
                        // Apply VCR distortion
                        try ComputePass {
                            try VCRDistortionPipeline(
                                inputTexture: videoTexture,
                                outputTexture: distortedTexture,
                                parameters: vcrParameters,
                                frameUniforms: context.frameUniforms
                            )
                        }

                        // Render the distorted texture
                        try RenderPass {
                            try TextureBillboardPipeline(specifier: .texture2D(distortedTexture))
                        }
                    } else {
                        // Render original video without effects
                        try RenderPass {
                            try TextureBillboardPipeline(specifier: .texture2D(videoTexture))
                        }
                    }
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
        }
        .demoConfiguration {
            HStack(alignment: .top, spacing: 20) {
                Form {
                    Button(action: togglePlayPause) {
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .disabled(videoURL == nil)

                    Button("Load Video") {
                        selectVideo()
                    }

                    Toggle("VCR Effects", isOn: $enableVCR)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .fixedSize()

                if enableVCR {
                    HStack(alignment: .top, spacing: 16) {
                        Form {
                            Button("Set All to Zero") {
                                vcrParameters.curvature = 0
                                vcrParameters.skip = 0
                                vcrParameters.imageFlicker = 0
                                vcrParameters.vignetteFlickerSpeed = 0
                                vcrParameters.vignetteStrength = 0
                                vcrParameters.smallScanlinesSpeed = 0
                                vcrParameters.smallScanlinesProximity = 0
                                vcrParameters.smallScanlinesOpacity = 0
                                vcrParameters.scanlinesOpacity = 0
                                vcrParameters.scanlinesSpeed = 0
                                vcrParameters.scanlineThickness = 0
                                vcrParameters.scanlinesSpacing = 0
                                vcrParameters.noiseAmount = 0
                                vcrParameters.chromaticAberration = 0
                            }
                            LabeledContent("Curvature") {
                                Slider(value: $vcrParameters.curvature, in: 0...10)
                            }
                            LabeledContent("Tracking") {
                                Slider(value: $vcrParameters.skip, in: 0...1)
                            }
                            LabeledContent("Flicker") {
                                Slider(value: $vcrParameters.imageFlicker, in: 0...2)
                            }
                            LabeledContent("Scanlines") {
                                Slider(value: $vcrParameters.scanlinesOpacity, in: 0...2)
                            }
                            LabeledContent("Vignette") {
                                Slider(value: $vcrParameters.vignetteStrength, in: 0...2)
                            }
                            LabeledContent("Noise") {
                                Slider(value: $vcrParameters.noiseAmount, in: 0...2)
                            }
                        }
                        .frame(width: 300)
                        Form {
                            LabeledContent("Color Shift") {
                                Slider(value: $vcrParameters.chromaticAberration, in: 0...2)
                            }
                            LabeledContent("Vignette Pulse") {
                                Slider(value: $vcrParameters.vignetteFlickerSpeed, in: 0...2)
                            }
                            LabeledContent("Scanline Speed") {
                                Slider(value: $vcrParameters.scanlinesSpeed, in: 0...2)
                            }
                            LabeledContent("Scanline Thickness") {
                                Slider(value: $vcrParameters.scanlineThickness, in: 0...1)
                            }
                            LabeledContent("Scanline Spacing") {
                                Slider(value: $vcrParameters.scanlinesSpacing, in: 0...2)
                            }
                            LabeledContent("Fast Scanlines") {
                                Slider(value: $vcrParameters.smallScanlinesOpacity, in: 0...2)
                            }
                            LabeledContent("Fast Scanline Speed") {
                                Slider(value: $vcrParameters.smallScanlinesSpeed, in: 0...2)
                            }
                            LabeledContent("Fast Scanline Density") {
                                Slider(value: $vcrParameters.smallScanlinesProximity, in: 0...2)
                            }
                        }
                        .frame(width: 300)
                    }
                }
            }
        }
        .onAppear {
            loadDefaultVideo()
        }
    }

    private func loadDefaultVideo() {
        if let url = Bundle.module.url(forResource: "sample", withExtension: "mov") ??
            Bundle.module.url(forResource: "sample", withExtension: "mp4") {
            loadVideo(url: url)
        } else if let url = videoURL {
            loadVideo(url: url)
        } else {
            errorMessage = "No default video found. Click 'Load Video' to select one."
        }
    }

    private func loadVideo(url: URL) {
        do {
            try videoPlayer.loadVideo(url: url, loopStart: 0, loopEnd: .infinity)
            videoURL = url
            errorMessage = nil
            videoPlayer.play()
            isPlaying = true
        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
        }
    }

    private func togglePlayPause() {
        if isPlaying {
            videoPlayer.pause()
        } else {
            videoPlayer.play()
        }
        isPlaying.toggle()
    }

    private func selectVideo() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            loadVideo(url: url)
        }
        #else
        errorMessage = "File selection not implemented on iOS"
        #endif
    }

    private func getOrCreateDistortedTexture(for videoTexture: MTLTexture) -> MTLTexture? {
        if distortedTexture == nil || distortedTexture?.width != videoTexture.width || distortedTexture?.height != videoTexture.height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: videoTexture.pixelFormat,
                width: videoTexture.width,
                height: videoTexture.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            distortedTexture = device.makeTexture(descriptor: descriptor)
            distortedTexture?.label = "VCR Distorted Texture"
        }
        return distortedTexture
    }
}
