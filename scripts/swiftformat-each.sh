#!/bin/bash

# Runs SwiftFormat on each Swift file in Sources/ and Tests/, one file at a
# time, with the repository's .swiftformat configuration.
# Usage: ./scripts/swiftformat-each.sh [--lint]
#
# SwiftFormat processes the files it is given in parallel, and stops a rule
# that takes longer than a time limit measured in wall-clock time. With all
# files at once, slower machines (such as GitHub's Linux runners, whose
# SwiftFormat build is also slower) fail with "organizeDeclarations rule
# timed out" and exit code 70 although nothing is wrong with the files. One
# file at a time stays well within the limit.
#
# Exit codes follow SwiftFormat's: 0 when every file is (now) formatted; with
# --lint, 1 when some files need formatting; otherwise the first other code
# SwiftFormat returned. Every file is processed, so all problems are listed.

set -euo pipefail

usage() {
    echo "Usage: $0 [--lint]"
    echo "  (no option)  Format each Swift file in Sources/ and Tests/"
    echo "  --lint       Only check; exit with 1 if any file needs formatting"
}

lint=false
if [ $# -gt 1 ]; then
    usage >&2
    exit 2
fi
if [ $# -eq 1 ]; then
    case "$1" in
        --lint) lint=true ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

for folder in Sources Tests; do
    if [ ! -d "$folder" ]; then
        echo "error: $folder/ not found" >&2
        exit 1
    fi
done

arguments=(--config .swiftformat)
if [ "$lint" = true ]; then
    arguments+=(--lint)
fi

files=0
needs_formatting=0
failure=0
while IFS= read -r -d '' file; do
    files=$((files + 1))
    status=0
    output="$(swiftformat "${arguments[@]}" "$file" 2>&1)" || status=$?
    # Keep SwiftFormat's errors and warnings, which include each lint
    # violation with its file, line and rule, but not its progress messages.
    printf '%s\n' "$output" | grep -E 'error:|warning:' || true
    if [ "$status" -eq 1 ] && [ "$lint" = true ]; then
        needs_formatting=$((needs_formatting + 1))
    elif [ "$status" -ne 0 ]; then
        echo "error: SwiftFormat failed with exit code $status for $file" >&2
        if [ "$failure" -eq 0 ]; then
            failure=$status
        fi
    fi
done < <(find Sources Tests -name '*.swift' -type f -print0 | sort -z)

if [ "$files" -eq 0 ]; then
    echo "error: no Swift files found in Sources/ or Tests/" >&2
    exit 1
fi
if [ "$failure" -ne 0 ]; then
    exit "$failure"
fi
if [ "$needs_formatting" -gt 0 ]; then
    echo "$needs_formatting of $files files need formatting." >&2
    exit 1
fi
if [ "$lint" = true ]; then
    echo "All $files files are formatted."
else
    echo "Formatted $files files."
fi
