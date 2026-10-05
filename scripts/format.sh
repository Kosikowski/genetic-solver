#!/bin/bash

# SwiftFormat script for local development
# Usage: ./scripts/format.sh [--check]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [--check]"
    echo "  (no option)  Format all Swift files in Sources/ and Tests/"
    echo "  --check      Only check formatting; exit with 1 if any file needs formatting"
}

# Determine if we're just checking or actually formatting. Unknown arguments
# are rejected so that a typo never formats files when a check was intended.
CHECK_ONLY=false
if [ $# -gt 1 ]; then
    echo -e "${RED}❌ Too many arguments${NC}" >&2
    usage >&2
    exit 2
fi
if [ $# -eq 1 ]; then
    case "$1" in
        --check)
            CHECK_ONLY=true
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown argument: $1${NC}" >&2
            usage >&2
            exit 2
            ;;
    esac
fi

# Run from the repository root so the paths below resolve no matter where
# the script is called from.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Check if SwiftFormat is installed
if ! command -v swiftformat &> /dev/null; then
    echo -e "${RED}❌ SwiftFormat is not installed${NC}"
    echo -e "${YELLOW}Install it with: brew install swiftformat${NC}"
    exit 1
fi

# Check if .swiftformat config exists
if [ ! -f ".swiftformat" ]; then
    echo -e "${RED}❌ .swiftformat configuration file not found${NC}"
    exit 1
fi

# Different SwiftFormat versions can format the same code differently, so
# warn when the installed version is not the one CI and pre-commit use.
PINNED_VERSION="$(./scripts/swiftformat-version.sh)"
INSTALLED_VERSION="$(swiftformat --version)"
if [ "$INSTALLED_VERSION" != "$PINNED_VERSION" ]; then
    echo -e "${YELLOW}⚠️  SwiftFormat $INSTALLED_VERSION is installed, but this project uses $PINNED_VERSION${NC}"
    echo -e "${YELLOW}   Results may differ from CI. The version is pinned in .pre-commit-config.yaml.${NC}"
fi

echo -e "${YELLOW}🔍 Checking code formatting...${NC}"

if [ "$CHECK_ONLY" = true ]; then
    # Just check formatting. SwiftFormat exits with 0 when everything is
    # formatted, 1 when some files need formatting, and another non-zero
    # code when it could not run (for example a missing input path).
    status=0
    swiftformat --lint --config .swiftformat Sources/ Tests/ || status=$?
    case $status in
        0)
            echo -e "${GREEN}✅ Code formatting is correct${NC}"
            ;;
        1)
            echo -e "${RED}❌ Code formatting issues found${NC}"
            echo -e "${YELLOW}Run ./scripts/format.sh to fix them${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}❌ SwiftFormat failed with exit code $status${NC}"
            exit "$status"
            ;;
    esac
else
    # Format the code
    echo -e "${YELLOW}🎨 Formatting code...${NC}"
    swiftformat --config .swiftformat Sources/ Tests/
    echo -e "${GREEN}✅ Code formatting completed${NC}"
fi
