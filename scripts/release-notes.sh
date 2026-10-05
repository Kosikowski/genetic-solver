#!/bin/bash

# Prints the notes that go above GitHub's generated notes in a release.
# Usage: ./scripts/release-notes.sh <tag> <owner/repo>
#
# Release tags are named v<semantic version>, for example v1.2.0 or
# v1.3.0-beta.1. Swift Package Manager versions have no "v" (`from: "v1.2.0"`
# is an invalid manifest), so the installation snippet drops it. Any other tag
# is rejected, so a release is never published with a snippet that can't
# resolve.

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <tag> <owner/repo>" >&2
    exit 2
fi

tag="$1"
repository="$2"

identifier='[0-9A-Za-z-]+'
semver="^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-$identifier(\.$identifier)*)?(\+$identifier(\.$identifier)*)?$"
if [[ ! "$tag" =~ $semver ]]; then
    echo "error: tag '$tag' is not v<semantic version>, for example v1.2.0" >&2
    exit 1
fi

if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "error: repository '$repository' is not <owner>/<repo>" >&2
    exit 1
fi

version="${tag#v}"

cat << EOF
## Installation

Add the package to your \`Package.swift\`:

\`\`\`swift
.package(url: "https://github.com/$repository.git", from: "$version"),
\`\`\`

See the [README](https://github.com/$repository#readme) for requirements and usage, and the [changelog](https://github.com/$repository/blob/$tag/CHANGELOG.md) for what changed and how to upgrade.
EOF
