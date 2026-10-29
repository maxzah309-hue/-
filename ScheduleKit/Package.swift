// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScheduleKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ScheduleKit", targets: ["ScheduleKit"]),
    ],
    targets: [
        .target(name: "ScheduleKit"),
        .testTarget(name: "ScheduleKitTests", dependencies: ["ScheduleKit"]),
    ]
)
