#!/bin/bash
#
# Build UniControl CLI and install to /Applications/UniControl.app
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

APP_BUNDLE="/Applications/UniControl.app"
BINARY_PATH="$APP_BUNDLE/Contents/MacOS/UniControl"

echo -e "${YELLOW}Building UniControl CLI (Release)...${NC}"

# Build in release mode
swift build -c release

# Get the built binary path
BUILD_PATH=$(swift build -c release --show-bin-path)
BUILT_BINARY="$BUILD_PATH/UniControl"

if [ ! -f "$BUILT_BINARY" ]; then
    echo -e "${RED}Error: Built binary not found at $BUILT_BINARY${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"
echo "Binary: $BUILT_BINARY"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}Error: $APP_BUNDLE does not exist${NC}"
    echo "Please install UniControlApp first."
    exit 1
fi

# Copy binary to app bundle
echo -e "${YELLOW}Installing to $BINARY_PATH...${NC}"
cp "$BUILT_BINARY" "$BINARY_PATH"
chmod +x "$BINARY_PATH"

echo -e "${GREEN}Done!${NC}"
echo ""
echo "UniControl CLI installed to: $BINARY_PATH"
echo ""
echo "You can run it with:"
echo "  $BINARY_PATH <script.unictl>"
echo "  $BINARY_PATH --mcp"
