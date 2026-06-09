// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownEditor",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MarkdownEditor",
            resources: [
                .copy("Resources/web")
            ]
        )
    ]
)
