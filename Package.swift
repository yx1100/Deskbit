// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Whatnote",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "Whatnote", targets: ["Whatnote"])
    ],
    targets: [
        .executableTarget(
            name: "Whatnote",
            path: "Sources/Whatnote"
        )
    ]
)
