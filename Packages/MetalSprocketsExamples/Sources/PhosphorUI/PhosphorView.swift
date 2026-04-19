import Metal
import MetalSprockets
import MetalSprocketsUI
import MetalSupport
import SwiftUI
import simd

/// A shader-toy style view that runs a user-supplied fragment snippet as a
/// `visible_function_table` entry inside a compute kernel, ping-ponging between
/// two backbuffer textures so snippets can sample the previous frame.
public struct PhosphorView: View {
    let snippet: String
    let style: SnippetStyle

    @State private var compiledFunction: MTLFunction?
    @State private var compileError: Error?

    public init(snippet: String, style: SnippetStyle = .twiglGeek) {
        self.snippet = snippet
        self.style = style
    }

    public var body: some View {
        ZStack {
            RenderView { context, drawableSize in
                PhosphorPipeline(
                    uniforms: PhosphorUniforms(
                        time: context.frameUniforms.time,
                        frame: Float(context.frameUniforms.index),
                        resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height)),
                        mouse: SIMD2<Float>(0.5, 0.5)
                    ),
                    snippetFunction: compiledFunction
                )
            }

            if let compileError {
                ContentUnavailableView(
                    "Shader Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(compileError.localizedDescription)
                )
                .padding()
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
                .padding()
            }
        }
        .task(id: SnippetKey(source: snippet, style: style)) {
            await recompile()
        }
    }

    private func recompile() async {
        do {
            let device = _MTLCreateSystemDefaultDevice()
            let expanded = expandSnippet(source: snippet, style: style)
            let function = try SnippetCompiler(device: device).compileSnippet(snippet: expanded)
            compiledFunction = function
            compileError = nil
        } catch {
            compiledFunction = nil
            compileError = error
        }
    }
}

private struct SnippetKey: Equatable {
    var source: String
    var style: SnippetStyle
}
