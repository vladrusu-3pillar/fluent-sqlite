import PackageDescription

let package = Package(
    name: "FluentSQLite",
    dependencies: [
        .Package(url: "https://github.com/qutheory/fluent.git", majorVersion: 0)
    ]
)