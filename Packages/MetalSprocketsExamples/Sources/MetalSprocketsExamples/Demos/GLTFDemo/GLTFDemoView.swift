import DemoKit
import MetalSprocketsExamplesSupport
import MetalSprocketsUI
import SwiftGLTF
import SwiftUI
import UniformTypeIdentifiers

public struct GLTFDemoView: View {
    @State
    private var url: URL?

    @State
    private var document: SwiftGLTF.Document?

    @State
    private var sceneGraph: SceneGraph?

    @State
    private var downloadedPath: URL?

    @State
    private var showingFilePicker = false

    @State
    private var availableFiles: [URL] = []

    public init() {
        if let defaultURL = Bundle.module.url(forResource: "VirtualCity", withExtension: "glb") {
            _url = State(initialValue: defaultURL)
        }
    }

    public var body: some View {
        VStack {
            if let sceneGraph {
                SceneGraphDemoView(sceneGraph: sceneGraph)
            } else {
                ContentUnavailableView("No Model Loaded", systemImage: "cube", description: Text("Use the configuration panel to load a glTF model."))
            }
        }
        .demoConfiguration {
            Form {
                let downloadURL = URL(string: "https://github.com/KhronosGroup/glTF-Sample-Assets/archive/refs/heads/main.zip").orFatalError("Failed to create url")
                DownloadButton(url: downloadURL, destinationName: "GLTFDownloads") { path in
                    downloadedPath = path
                    loadAvailableFiles(from: path)
                }

                if downloadedPath != nil, !availableFiles.isEmpty {
                    Button("Browse Files") {
                        showingFilePicker = true
                    }
                }
                #if os(macOS)
                if let downloadedPath {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadedPath.path)
                    }
                }
                #endif

                SuperImportWidget(url: $url, identifier: "GLTFDemo", allowedContentTypes: [.gltf, .glb])
                if let url {
                    Text(url.lastPathComponent)
                        .font(.caption)
                }
                if let document {
                    Text("\(document.scenes.count) scene(s), \(document.meshes.count) mesh(es)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .onChange(of: url, initial: true) {
            do {
                guard let url else {
                    return
                }
                let container = try Container(url: url)
                document = container.document
                sceneGraph = try GLTGSceneGraphGenerator(container: container).generateSceneGraph()
            }
            catch {
                fatalError("Failed to load GLTF: \(error)")
            }
        }
        .onChange(of: downloadedPath) {
            if let path = downloadedPath {
                loadAvailableFiles(from: path)
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            GLTFFilePickerView(files: availableFiles, selectedURL: $url, isPresented: $showingFilePicker)
        }
    }

    private func loadAvailableFiles(from path: URL) {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path.path) else {
            return
        }

        let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: [.isRegularFileKey])

        var files: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            let pathExtension = fileURL.pathExtension.lowercased()
            if pathExtension == "gltf" || pathExtension == "glb" {
                files.append(fileURL)
            }
        }

        availableFiles = files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

extension UTType {
    static let gltf = UTType(filenameExtension: "gltf").orFatalError("Failed to create UTType for .gltf")
    static let glb = UTType(filenameExtension: "glb").orFatalError("Failed to create UTType for .glb")
}
