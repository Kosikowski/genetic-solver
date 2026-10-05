#!/bin/bash

# Builds and runs Tests/Swift6Client/main.swift as a separate package in the
# Swift 6 language mode that depends on this one, with warnings as errors.
# This package and its tests use the Swift 5 language mode, which doesn't
# enforce Sendable, so this catches problems that only Swift 6 clients see,
# such as a public value type that isn't Sendable. Needs Swift 6.0 or later.
# Usage: ./scripts/test-swift6-client.sh

set -euo pipefail

if [ $# -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."
repository="$PWD"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# SwiftPM names a local dependency after its folder, so the client depends on
# a link called genetic-solver, whatever this repository's folder is called.
ln -s "$repository" "$work/genetic-solver"
mkdir -p "$work/Swift6Client/Sources/Swift6Client"
cp Tests/Swift6Client/main.swift "$work/Swift6Client/Sources/Swift6Client/main.swift"
cat > "$work/Swift6Client/Package.swift" << 'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Swift6Client",
    // Only for this executable: the Swift libraries of recent Xcode versions
    // are built for macOS 13, and the linker warns for older targets.
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../genetic-solver")],
    targets: [
        .executableTarget(
            name: "Swift6Client",
            dependencies: [.product(name: "genetic-solver", package: "genetic-solver")]
        ),
    ]
)
EOF

swift build --package-path "$work/Swift6Client" -Xswiftc -warnings-as-errors
swift run --package-path "$work/Swift6Client" --skip-build Swift6Client
