#!/bin/bash

# Builds the library the way binary frameworks (XCFrameworks) are built:
# with library evolution, emitting its module interface (.swiftinterface)
# and checking that the interface compiles, in the Swift 6 language mode the
# package uses, with warnings as errors. The interface contains the
# library's inlinable code (see the comment above GeneticSolver), and
# library evolution puts extra limits on that code, so a change can pass
# every other build and still break this one.
# Usage: ./scripts/check-library-evolution.sh

set -euo pipefail

if [ $# -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

swiftc -swift-version 6 -parse-as-library -module-name genetic_solver \
    -enable-library-evolution -warnings-as-errors \
    -emit-module -emit-module-path "$work/genetic_solver.swiftmodule" \
    -emit-module-interface-path "$work/genetic_solver.swiftinterface" \
    -verify-emitted-module-interface \
    Sources/genetic-solver/*.swift
echo "The library builds with library evolution, and its module interface compiles"
