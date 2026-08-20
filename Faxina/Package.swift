// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Faxina",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Faxina",
            path: "Sources/Faxina",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
