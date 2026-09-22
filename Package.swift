// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BLM-TTY",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BLM-TTY", targets: ["BLMTTY"])
    ],
    targets: [
        .executableTarget(
            name: "BLMTTY",
            path: "Sources",
            exclude: [
                "App/Info.plist"
            ],
            publicHeadersPath: "Net",
            cSettings: [
                .headerSearchPath("Net")
            ]
        )
    ]
)
