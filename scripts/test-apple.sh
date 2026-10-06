#!/bin/bash

# Builds and tests the package for one Apple platform with the selected Xcode.
# Usage: ./scripts/test-apple.sh macOS|iOS|tvOS|watchOS|visionOS
#
# macOS runs `swift test`. The other platforms run `xcodebuild test` on a
# simulator chosen from the destinations Xcode reports for the package: the
# newest one whose OS version is not newer than the selected Xcode's SDK, so
# each Xcode version is tested on its own OS version (or, if there is none,
# the newest one). The script works with whichever simulators are installed,
# on CI and locally.
#
# Right after Xcode is selected, GitHub's macOS runners sometimes report no
# simulators at all, so the script asks again before giving up. Two
# environment variables change how long it waits (CI uses the defaults):
#   SIMULATOR_WAIT_ATTEMPTS  how many times to ask (default 6)
#   SIMULATOR_WAIT_SECONDS   seconds between attempts (default 15)

set -euo pipefail

SCHEME="genetic-solver"

usage() {
    echo "Usage: $0 macOS|iOS|tvOS|watchOS|visionOS"
}

if [ $# -ne 1 ]; then
    usage >&2
    exit 2
fi
platform="$1"

case "$platform" in
    macOS) ;;
    iOS) sdk=iphonesimulator ;;
    tvOS) sdk=appletvsimulator ;;
    watchOS) sdk=watchsimulator ;;
    visionOS) sdk=xrsimulator ;;
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

attempts="${SIMULATOR_WAIT_ATTEMPTS:-6}"
delay="${SIMULATOR_WAIT_SECONDS:-15}"
if ! [[ "$attempts" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: SIMULATOR_WAIT_ATTEMPTS must be a whole number of at least 1, but is '$attempts'" >&2
    exit 2
fi
if ! [[ "$delay" =~ ^[0-9]+$ ]]; then
    echo "error: SIMULATOR_WAIT_SECONDS must be a whole number, but is '$delay'" >&2
    exit 2
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ "$platform" = macOS ]; then
    swift build
    swift test
    exit 0
fi

sdk_version="$(xcrun --sdk "$sdk" --show-sdk-version)"

# Listing the simulators starts the simulator service if it isn't running.
xcrun simctl list devices available > /dev/null

# Destination lines look like:
#   { platform:iOS Simulator, arch:arm64, id:<UDID>, OS:18.5, name:iPhone 16 }
# Placeholders such as "Any iOS Simulator Device" have no OS and are skipped.
# `sed -n ... p` prints only matching lines and, unlike grep, succeeds when
# nothing matches, so the error below is reported instead of `set -e`
# stopping the script silently. Each simulator becomes "OS|id|name".
simulators=""
for ((attempt = 1; attempt <= attempts; attempt++)); do
    destinations="$(xcodebuild -showdestinations -scheme "$SCHEME")"
    simulators="$(
        printf '%s\n' "$destinations" |
            sed -nE "/platform:$platform Simulator,/ s/.*[{ ,]id:([^,]+),.*[{ ,]OS:([0-9.]+),.*name:([^}]*[^ }]).*/\2|\1|\3/p"
    )"
    if [ -n "$simulators" ]; then
        break
    fi
    if [ "$attempt" -lt "$attempts" ]; then
        echo "No $platform simulator reported yet (attempt $attempt of $attempts); asking again in ${delay}s" >&2
        sleep "$delay"
    fi
done

if [ -z "$simulators" ]; then
    echo "error: no $platform simulator is available for the selected Xcode" >&2
    echo "Destinations reported by xcodebuild:" >&2
    printf '%s\n' "$destinations" >&2
    echo "Simulators reported by simctl:" >&2
    xcrun simctl list runtimes >&2 || true
    xcrun simctl list devices available >&2 || true
    exit 1
fi

# Keep the simulators whose OS version is at most the SDK version: the larger
# of the two versions, by `sort -V`, is then the SDK version.
supported=""
while IFS='|' read -r os_version device_id device_name; do
    if [ "$(printf '%s\n%s\n' "$os_version" "$sdk_version" | sort -V | tail -n 1)" = "$sdk_version" ]; then
        supported+="$os_version|$device_id|$device_name"$'\n'
    fi
done <<< "$simulators"

if [ -n "$supported" ]; then
    candidates="$supported"
else
    echo "note: no $platform simulator has an OS version up to the $sdk SDK ($sdk_version); using the newest one" >&2
    candidates="$simulators"
fi

newest="$(printf '%s' "$candidates" | sort -t '|' -k1,1V | tail -n 1)"
IFS='|' read -r os_version device_id device_name <<< "$newest"
echo "Testing on $device_name ($platform $os_version, $device_id) with the $sdk SDK $sdk_version"

xcodebuild test -scheme "$SCHEME" -destination "id=$device_id"
