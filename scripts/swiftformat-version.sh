#!/bin/bash

# Prints the SwiftFormat version this project uses.
# Usage: ./scripts/swiftformat-version.sh
#
# The version is pinned once, as the `rev` of the SwiftFormat repo in
# .pre-commit-config.yaml. The pre-commit hook uses it directly, and the CI
# workflows and scripts/format.sh read it through this script, so all of
# them format code the same way.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ ! -f .pre-commit-config.yaml ]; then
    echo "error: .pre-commit-config.yaml not found" >&2
    exit 1
fi

version="$(
    awk '
        /repo:/ { in_swiftformat = ($0 ~ /github\.com\/nicklockwood\/SwiftFormat(\.git)?([[:space:]]|$)/) }
        in_swiftformat && $1 == "rev:" { print $2; exit }
    ' .pre-commit-config.yaml | tr -d "\"'"
)"

if [ -z "$version" ]; then
    echo "error: no SwiftFormat rev found in .pre-commit-config.yaml" >&2
    exit 1
fi

echo "$version"
