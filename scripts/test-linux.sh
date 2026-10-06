#!/bin/bash

# Builds and tests the package on Linux in the official Swift Docker images,
# in debug and release, like the Linux CI workflow. Requires Docker.
# Usage: ./scripts/test-linux.sh [swift-version ...]
#
# Without arguments it uses the Swift versions from the Linux CI matrix.

set -euo pipefail

# Keep in sync with the swift-version matrix in .github/workflows/linux.yml.
DEFAULT_VERSIONS=(6.1.2)

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v docker &> /dev/null; then
    echo "error: Docker is not installed" >&2
    exit 1
fi
if ! docker info &> /dev/null; then
    echo "error: the Docker daemon is not running" >&2
    exit 1
fi

if [ $# -gt 0 ]; then
    versions=("$@")
else
    versions=("${DEFAULT_VERSIONS[@]}")
fi

for version in "${versions[@]}"; do
    for configuration in debug release; do
        echo "=== Swift $version ($configuration)"
        # The working tree is mounted read-only and the build goes to a folder
        # inside the container, so nothing in the working tree changes.
        docker run --rm -v "$PWD":/src:ro -w /src "swift:$version" \
            swift test -c "$configuration" --scratch-path /tmp/build
    done
done

echo "✅ All Linux builds and tests passed"
