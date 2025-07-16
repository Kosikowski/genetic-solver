#!/bin/bash

# SwiftFormat script for local development
# Usage: ./scripts/format.sh [--check]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Determine if we're just checking or actually formatting
CHECK_ONLY=false
if [[ "$1" == "--check" ]]; then
    CHECK_ONLY=true
fi

echo -e "${YELLOW}🔍 Checking code formatting...${NC}"

if [ "$CHECK_ONLY" = true ]; then
    # Just check formatting
    if swiftformat --lint --config .swiftformat Sources/ Tests/ | grep -q "would have been formatted"; then
        echo -e "${RED}❌ Code formatting issues found${NC}"
        swiftformat --lint --config .swiftformat Sources/ Tests/
        exit 1
    else
        echo -e "${GREEN}✅ Code formatting is correct${NC}"
    fi
else
    # Format the code
    echo -e "${YELLOW}🎨 Formatting code...${NC}"
    swiftformat --config .swiftformat Sources/ Tests/
    echo -e "${GREEN}✅ Code formatting completed${NC}"
fi
