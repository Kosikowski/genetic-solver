#!/bin/bash

# Builds and runs Tests/Swift6Client/main.swift as a separate package in the
# Swift 6 language mode that depends on this one, with warnings as errors.
# The tests import the library with @testable, which also gives them its
# internal declarations; this client uses only the public API, as other
# packages do, so it catches problems such as a public value type that isn't
# Sendable or something only reachable through internal access.
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
// swift-tools-version: 6.1
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
