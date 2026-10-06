#!/bin/bash

# Builds Tests/Benchmark/main.swift in release mode as a separate package
# that depends on this one, and runs it. The library's generic code is
# specialized for a client's types in the client's module, so it is measured
# from a separate package, the way clients use it.
#
# Each scenario runs the same seeded configuration <repetitions> times
# (default 5). The benchmark prints the best and median times and the best
# fitness found, and fails if the runs don't all find the same fitness.
# Timings vary between machines and runs; compare them on one machine.
# Usage: ./scripts/benchmark.sh [repetitions]

set -euo pipefail

usage() {
    echo "Usage: $0 [repetitions]"
    echo "  repetitions  How often to run each scenario (a positive integer, default 5)"
}

if [ $# -gt 1 ]; then
    usage >&2
    exit 2
fi
repetitions="${1:-5}"
case "$repetitions" in
    -h | --help)
        usage
        exit 0
        ;;
esac
if ! [[ "$repetitions" =~ ^[1-9][0-9]{0,5}$ ]]; then
    echo "error: repetitions must be a positive integer below 1000000: $repetitions" >&2
    usage >&2
    exit 2
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."
repository="$PWD"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# SwiftPM names a local dependency after its folder, so the benchmark depends
# on a link called genetic-solver, whatever this repository's folder is called.
ln -s "$repository" "$work/genetic-solver"
mkdir -p "$work/Benchmark/Sources/Benchmark"
cp Tests/Benchmark/main.swift "$work/Benchmark/Sources/Benchmark/main.swift"
cat > "$work/Benchmark/Package.swift" << 'PACKAGE'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Benchmark",
    // Only for this executable, which uses ContinuousClock.
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../genetic-solver")],
    targets: [
        .executableTarget(
            name: "Benchmark",
            dependencies: [.product(name: "genetic-solver", package: "genetic-solver")]
        ),
    ]
)
PACKAGE

swift build --package-path "$work/Benchmark" -c release -Xswiftc -warnings-as-errors
swift run --package-path "$work/Benchmark" -c release --skip-build Benchmark "$repetitions"
