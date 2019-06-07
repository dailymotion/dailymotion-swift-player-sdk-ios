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
            path: "DailymotionPlayerSDK"
        )
    ]
)
