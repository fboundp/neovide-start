// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "neovide-start",
  platforms: [.macOS(.v14) ],
  targets: [
    .executableTarget(
      name: "neovide-start",
      dependencies: ["Wait"],
      path: "Sources"),
    .systemLibrary(
      name: "Wait",
      path: "Modules"),
  ]
)
