// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
		name: "NearDropPlusPlus",
		platforms: [
				.macOS(.v10_15)
		],
		products: [
				.library(
						name: "NearDropPlusPlus",
						targets: ["NearDropPlusPlus"]),
		],
		dependencies: [
				// List your dependencies here
				.package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.1"),
				.package(url: "https://github.com/leif-ibsen/BigInt", from: "1.19.0"),
				.package(url: "https://github.com/leif-ibsen/ASN1", from: "2.6.0"),
				.package(url: "https://github.com/leif-ibsen/SwiftECC", from: "3.9.0"),
		],
		targets: [
				.target(
						name: "NearDropPlusPlus",
						dependencies: ["SwiftProtobuf", "BigInt", "ASN1", "SwiftECC"],
						path: "./NearDrop"
				),
		]
)

