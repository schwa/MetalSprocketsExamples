XCODE_PROJECT := "MetalSprockets-Examples.xcodeproj"
XCODE_SCHEME := "MetalSprockets-Examples"
CONFIGURATION := "Debug"

default: list

list:
    just --list

build-macOS:
    xcodebuild \
        -scheme "{{ XCODE_SCHEME }}" \
        -configuration "{{ CONFIGURATION }}" \
        -destination 'platform=macOS,name=Any Mac' \
        build | xcpretty
    @echo "✅ macOS Build Success"

build-iOS:
    xcodebuild \
        -scheme "{{ XCODE_SCHEME }}" \
        -configuration "{{ CONFIGURATION }}" \
        -destination 'platform=iOS,name=Any iOS Device' \
        build | xcpretty
    xcodebuild \
        -scheme "{{ XCODE_SCHEME }}" \
        -configuration "{{ CONFIGURATION }}" \
        -destination 'platform=iOS Simulator,name=Any iOS Simulator Device' \
        build | xcpretty
    @echo "✅ iOS Build Success"

build: build-macOS build-iOS
    @echo "✅ Build Success"

test:
    swift test --quiet --package-path Packages/MetalSprocketsExamples
    @echo "✅ Test Success"

push: build test
    jj bookmark move main --to @-; jj git push --branch main

format:
    swiftlint --fix --format --quiet
    fd --extension metal --extension h --exec clang-format -i {}

PACKAGE_SWIFT := "Packages/MetalSprocketsExamples/Package.swift"

# Use local MetalSprockets from /Users/schwa/Projects/MetalSprockets
use-local:
    sed -i '' 's|^        .package(url: "https://github.com/schwa/MetalSprockets", branch: "main"),|//        .package(url: "https://github.com/schwa/MetalSprockets", branch: "main"),|' {{PACKAGE_SWIFT}}
    sed -i '' 's|^//        .package(path: "/Users/schwa/Projects/MetalSprockets"),|        .package(path: "/Users/schwa/Projects/MetalSprockets"),|' {{PACKAGE_SWIFT}}
    @echo "Switched to local MetalSprockets"

# Use remote MetalSprockets from GitHub main branch
use-remote:
    sed -i '' 's|^        .package(path: "/Users/schwa/Projects/MetalSprockets"),|//        .package(path: "/Users/schwa/Projects/MetalSprockets"),|' {{PACKAGE_SWIFT}}
    sed -i '' 's|^//        .package(url: "https://github.com/schwa/MetalSprockets", branch: "main"),|        .package(url: "https://github.com/schwa/MetalSprockets", branch: "main"),|' {{PACKAGE_SWIFT}}
    @echo "Switched to remote MetalSprockets"

update-deps:
    rm Packages/MetalSprocketsExamples/Package.resolved
    #rm MetalSprockets-Examples.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    cd Packages/MetalSprocketsExamples; swift package update
    xcodebuild -resolvePackageDependencies
