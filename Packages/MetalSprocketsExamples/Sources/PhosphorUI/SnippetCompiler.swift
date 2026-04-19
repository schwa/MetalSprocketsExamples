import Foundation
import Metal

struct SnippetCompiler {
    let device: MTLDevice

    func compileSnippet(snippet: String) throws -> MTLFunction {
        let snippetLibrary = try device.makeLibrary(source: snippet, options: nil)
        let functionDescriptor = MTLFunctionDescriptor()
        functionDescriptor.name = "snippet"
        return try snippetLibrary.makeFunction(descriptor: functionDescriptor)
    }
}
