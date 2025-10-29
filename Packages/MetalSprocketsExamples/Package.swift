// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MetalSprocketsExamples",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
        .visionOS("26.0")
    ],
    products: [
        .library(name: "MetalSprocketsExamples", targets: ["MetalSprocketsExamples"]),
        .library(name: "MetalSprocketsAddOns", targets: ["MetalSprocketsAddOns"]),
        .library(name: "CaptureExample", targets: ["CaptureExample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.2.0"),
        .package(url: "https://github.com/schwa/earcut-swift", from: "0.1.0"),
        .package(url: "https://github.com/schwa/Everything", from: "1.2.0"),
        .package(url: "https://github.com/schwa/GeometryLite3D", exact: "0.1.0-alpha.3"),
        .package(url: "https://github.com/schwa/Interaction3D", exact: "0.1.0-alpha.1"),
        .package(url: "https://github.com/schwa/MetalCompilerPlugin", from: "0.1.3"),
//        .package(path: "/Users/schwa/Projects//MetalCompilerPlugin"),
        .package(url: "https://github.com/schwa/MetalSprockets", branch: "main"),
//        .package(url: "https://github.com/schwa/MetalSprocketsAddOns", branch: "main"),
//        .package(path: "/Users/schwa/Projects/MetalSprocketsAddOns"),
        .package(url: "https://github.com/schwa/Panels", from: "0.1.0"),
        .package(url: "https://github.com/schwa/SwiftGLTF", branch: "main"),
        .package(url: "https://github.com/SomeRandomiOSDev/CBORCoding", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0-latest"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "MetalSprocketsExamples",
            dependencies: [
                "MetalSprocketsExampleShaders",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "earcut", package: "earcut-swift"),
                .product(name: "Everything", package: "Everything"),
                .product(name: "GeometryLite3D", package: "GeometryLite3D"),
                .product(name: "Interaction3D", package: "Interaction3D"),
                .product(name: "MetalSprockets", package: "MetalSprockets"),
                .product(name: "MetalSprocketsUI", package: "MetalSprockets"),
                "MetalSprocketsAddOns",
                "MetalSprocketsAddOnsShaders",
                .product(name: "Panels", package: "Panels"),
                .product(name: "SwiftGLTF", package: "SwiftGLTF"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            resources: [
                .copy("Resources/4.2.03.heic"),
                .copy("Resources/AppleEventVideo.mp4"),
                .copy("Resources/AppleLogoMask.png"),
                .copy("Resources/DJSI3956.JPG"),
                .copy("Resources/DSC_2595.JPG"),
                .copy("Resources/HD-Testcard-original.jpg"),
                .copy("Resources/IndoorEnvironmentHDRI013_1K-HDR.exr"),
                .copy("Resources/Samples"),
                .copy("Resources/teapot.obj"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        .target(
            name: "MetalSprocketsExampleShaders",
            dependencies: [
                "MetalSprocketsAddOnsShaders"
            ],
            exclude: ["Metal"],
//            publicHeadersPath: ".",
            plugins: [
                .plugin(name: "MetalCompilerPlugin", package: "MetalCompilerPlugin")
            ],
        ),
        .testTarget(
            name: "MetalSprocketsExamplesTests",
            dependencies: ["MetalSprocketsExamples"],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        .target(
            name: "MetalSprocketsAddOns",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "GeometryLite3D", package: "GeometryLite3D"),
                .product(name: "MetalSprockets", package: "MetalSprockets"),
                .product(name: "earcut", package: "earcut-swift"),
                "MetalSprocketsAddOnsShaders",
                "MikkTSpace",
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
        ),
        .target(
            name: "MetalSprocketsAddOnsShaders",
            exclude: ["Metal"],
//            publicHeadersPath: ".",
            plugins: [
                .plugin(name: "MetalCompilerPlugin", package: "MetalCompilerPlugin")
            ]
        ),
        .target(
            name: "MikkTSpace",
            publicHeadersPath: ".",
        ),

        .target(
            name: "CaptureExample",
            dependencies: [
                "MetalSprocketsExampleShaders",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "CBORCoding", package: "CBORCoding"),
                .product(name: "earcut", package: "earcut-swift"),
                .product(name: "MetalSprockets", package: "MetalSprockets"),
                .product(name: "MetalSprocketsUI", package: "MetalSprockets"),
                "MetalSprocketsAddOns",
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
