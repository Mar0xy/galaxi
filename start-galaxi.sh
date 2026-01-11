#!/bin/bash

# Combined startup script for Galaxi
# Starts TypeScript/Bun backend server and Flutter app
# Stops server when app exits

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Starting Galaxi ===${NC}"

# Check if standalone executable exists
if [ -f "typescript/galaxi-backend" ] && [ -x "typescript/galaxi-backend" ]; then
    echo -e "${GREEN}Using standalone backend executable${NC}"
    cd typescript
    ./galaxi-backend &
    SERVER_PID=$!
    cd ..
else
    # Check if Bun is installed
    if ! command -v bun &> /dev/null; then
        echo -e "${RED}Bun is not installed and no standalone executable found.${NC}"
        echo -e "${YELLOW}Please install Bun from https://bun.sh or build the executable:${NC}"
        echo -e "${YELLOW}  cd typescript && bun run build${NC}"
        exit 1
    fi

    # Check if dependencies are installed
    if [ ! -d "typescript/node_modules" ]; then
        echo -e "${YELLOW}Installing backend dependencies...${NC}"
        cd typescript
        bun install
        cd ..
    fi

    # Start backend server with Bun in background
    echo -e "${GREEN}Starting backend server with Bun...${NC}"
    cd typescript
    bun run start &
    SERVER_PID=$!
    cd ..
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
        wait $SERVER_PID 2>/dev/null
        echo -e "${GREEN}Backend server stopped${NC}"
    fi
}

# Register cleanup on exit
trap cleanup EXIT INT TERM

# Start Flutter app
echo -e "${GREEN}Starting Flutter app...${NC}"
./galaxi

# When flutter exits, cleanup will automatically run
