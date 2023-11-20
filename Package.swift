// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DownloaderKit",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DownloaderKit",
            targets: ["DownloaderKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.8.1")),
        .package(url: "https://github.com/RxSwiftCommunity/RxAlamofire.git", from: "6.1.2"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.6.0")),
        .package(url: "https://github.com/realm/realm-swift.git", .upToNextMajor(from: "10.44.0")),
        .package(url: "https://github.com/RxSwiftCommunity/RxRealm.git", from: "5.0.6")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DownloaderKit",
            dependencies: [
                .product(name: "RxRelay", package: "RxSwift"),
                .product(name: "RealmSwift", package: "realm-swift"),
                "Alamofire",
                "RxAlamofire",
                "RxSwift",
                "RxRealm"
            ]
        ),
        .testTarget(
            name: "DownloaderKitTests",
            dependencies: ["DownloaderKit"]
        ),
    ]
)
