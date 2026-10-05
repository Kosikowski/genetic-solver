#!/bin/bash

# Downloads the SwiftFormat release pinned in .pre-commit-config.yaml.
# Usage: ./scripts/install-swiftformat.sh <folder>
#
# Afterwards <folder>/swiftformat is the pinned version. Works on macOS and on
# Linux (x86_64 and aarch64), and needs curl and unzip. The downloaded zip is
# left in <folder>.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <folder>" >&2
    exit 2
fi
destination="$1"

script_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
version="$("$script_folder/swiftformat-version.sh")"

# Each release has one zip per platform, and the Linux zips name the binary
# after the platform.
case "$(uname -s)/$(uname -m)" in
    Darwin/*)
        asset=swiftformat.zip
        binary=swiftformat
        ;;
    Linux/x86_64)
        asset=swiftformat_linux.zip
        binary=swiftformat_linux
        ;;
    Linux/aarch64 | Linux/arm64)
        asset=swiftformat_linux_aarch64.zip
        binary=swiftformat_linux_aarch64
        ;;
    *)
        echo "error: SwiftFormat has no release for $(uname -s) $(uname -m)" >&2
        exit 1
        ;;
esac

mkdir -p "$destination"
curl -fsSL --retry 3 -o "$destination/$asset" \
    "https://github.com/nicklockwood/SwiftFormat/releases/download/$version/$asset"
unzip -o -q "$destination/$asset" "$binary" -d "$destination"
if [ "$binary" != swiftformat ]; then
    mv -f "$destination/$binary" "$destination/swiftformat"
fi
chmod +x "$destination/swiftformat"

installed="$("$destination/swiftformat" --version)"
if [ "$installed" != "$version" ]; then
    echo "error: downloaded SwiftFormat $installed, expected $version" >&2
    exit 1
fi
echo "Installed SwiftFormat $version to $destination/swiftformat"
