// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "DailymotionPlayerSDK",
    platforms: [.iOS("8.0")],
    products: [
        .library(name: "DailymotionPlayerSDK", targets: ["DailymotionPlayerSDK"])
    ],
    targets: [
        .target(
            name: "DailymotionPlayerSDK",
            dependencies: ["OMSDK_Dailymotion"],
            path: "DailymotionPlayerSDK",
            exclude:["Info.plist"],
            resources: [
              .process("omsdk-v1.js")
            ]
        ),
        .binaryTarget(name: "OMSDK_Dailymotion", path: "OMSDK_Dailymotion.xcframework")
    ]
)
