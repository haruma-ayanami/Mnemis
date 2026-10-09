// swift-tools-version: 6.0
import PackageDescription

// Ядро Mnemis: модели данных, алгоритм повторений, словарь и поиск.
// Без UI, поэтому тестируется через `swift test` без симулятора.
let package = Package(
    name: "MnemisCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "MnemisCore", targets: ["MnemisCore"]),
    ],
    targets: [
        .target(name: "MnemisCore"),
        .testTarget(name: "MnemisCoreTests", dependencies: ["MnemisCore"]),
    ]
)
