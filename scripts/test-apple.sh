#!/bin/bash

# Builds and tests the package for one Apple platform with the selected Xcode.
# Usage: ./scripts/test-apple.sh macOS|iOS|tvOS|visionOS
#
# macOS runs `swift test`. The other platforms run `xcodebuild test` on a
# simulator. The simulator is chosen from the destinations Xcode reports for
# the package (the newest OS version), so the script works with whichever
# simulators the selected Xcode supports, on CI and locally.

set -euo pipefail

SCHEME="genetic-solver"

usage() {
    echo "Usage: $0 macOS|iOS|tvOS|visionOS"
}

if [ $# -ne 1 ]; then
    usage >&2
    exit 2
fi
platform="$1"

case "$platform" in
    macOS | iOS | tvOS | visionOS) ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "error: unknown platform: $platform" >&2
        usage >&2
        exit 2
        ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ "$platform" = macOS ]; then
    swift build
    swift test
    exit 0
fi

# Destination lines look like:
#   { platform:iOS Simulator, arch:arm64, id:<UDID>, OS:18.5, name:iPhone 16 }
# Placeholders such as "Any iOS Simulator Device" have no OS and are skipped.
# `sed -n ... p` prints only matching lines and, unlike grep, succeeds when
# nothing matches, so the error below is reported instead of `set -e`
# stopping the script silently.
destinations="$(xcodebuild -showdestinations -scheme "$SCHEME")"
newest="$(
    printf '%s\n' "$destinations" |
        sed -nE "/platform:$platform Simulator,/ s/.*[{ ,]id:([^,]+),.*[{ ,]OS:([0-9.]+),.*name:([^}]*[^ }]).*/\2|\1|\3/p" |
        sort -t '|' -k1,1V |
        tail -n 1
)"

if [ -z "$newest" ]; then
    echo "error: no $platform simulator is available for the selected Xcode" >&2
    echo "Destinations reported by xcodebuild:" >&2
    printf '%s\n' "$destinations" >&2
    exit 1
fi

IFS='|' read -r os_version device_id device_name <<< "$newest"
echo "Testing on $device_name ($platform $os_version, $device_id)"

xcodebuild test -scheme "$SCHEME" -destination "id=$device_id"
