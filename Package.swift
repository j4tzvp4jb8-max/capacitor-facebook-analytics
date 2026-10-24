// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorFacebookAnalytics",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapgoCapacitorFacebookAnalytics",
            targets: ["FacebookAnalyticsPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0"),
        // GymIsLife fork (24 Oct 2026): pinned EXACTLY. 19.0.0 is the first release whose
        // FacebookAutoLogAppEventsEnabled=false cannot be overridden from Events Manager, and the first
        // with the FBSDKAutoLogMetaDataEnabled / FBSDKAutoLogProductImprovementEnabled opt-outs.
        .package(url: "https://github.com/facebook/facebook-ios-sdk.git", exact: "19.0.0")
    ],
    targets: [
        .target(
            name: "FacebookAnalyticsPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "FacebookCore", package: "facebook-ios-sdk")
            ],
            path: "ios/Sources/FacebookAnalyticsPlugin"),
        .testTarget(
            name: "FacebookAnalyticsPluginTests",
            dependencies: ["FacebookAnalyticsPlugin"],
            path: "ios/Tests/FacebookAnalyticsPluginTests")
    ]
)
