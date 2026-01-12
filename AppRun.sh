#!/bin/bash

# AppImage startup script for Galaxi
# Starts backend server and Flutter app
# Stops server when app exits

set -e

# In AppImage, APPDIR is set to the mount point
APPDIR="${APPDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$APPDIR/usr/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Starting Galaxi ===${NC}"

# Check if standalone executable exists
if [ -f "backend/galaxi-backend" ] && [ -x "backend/galaxi-backend" ]; then
    echo -e "${GREEN}Using standalone backend executable${NC}"
    cd backend
    ./galaxi-backend &
    SERVER_PID=$!
    cd ..
else
    echo -e "${RED}Backend executable not found at backend/galaxi-backend${NC}"
    echo -e "${YELLOW}Please build or install the backend first.${NC}"
    exit 1
fi

# Give server time to start
sleep 2

# Check if server started successfully
if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo -e "${RED}Failed to start backend server${NC}"
    exit 1
fi

echo -e "${GREEN}Backend server started (PID: $SERVER_PID)${NC}"
echo -e "${GREEN}Server running on http://localhost:3000${NC}"

# Cleanup function to stop server
cleanup() {
    echo -e "\n${YELLOW}Stopping backend server...${NC}"
    if kill -0 $SERVER_PID 2>/dev/null; then
        kill $SERVER_PID
        wait $SERVER_PID 2>/dev/null || true
        echo -e "${GREEN}Backend server stopped${NC}"
    fi
}

# Register cleanup on exit
trap cleanup EXIT INT TERM

# Start Flutter app
echo -e "${GREEN}Starting Flutter app...${NC}"
./galaxi "$@"

# When flutter exits, cleanup will automatically run
