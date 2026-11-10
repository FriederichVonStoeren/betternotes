// swift-tools-version:5.9
import PackageDescription

// Core logic of betternotes: file format, geometry, sync. Foundation only, no UI.
let package = Package(
    name: "BetterNotesCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "BetterNotesCore", targets: ["BetterNotesCore"]),
    ],
    targets: [
        .target(name: "BetterNotesCore"),
        .testTarget(name: "BetterNotesCoreTests", dependencies: ["BetterNotesCore"]),
    ]
)
