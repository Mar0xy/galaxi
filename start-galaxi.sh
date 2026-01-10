#!/bin/bash

# Combined startup script for Galaxi
# Starts TypeScript backend server and Flutter app
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

# Check if TypeScript is set up
if [ ! -d "typescript/node_modules" ]; then
    echo -e "${YELLOW}Installing TypeScript dependencies...${NC}"
    cd typescript
    npm install
    cd ..
fi

# Build TypeScript if needed
if [ ! -d "typescript/dist" ]; then
    echo -e "${YELLOW}Building TypeScript backend...${NC}"
    cd typescript
    npm run build
    cd ..
fi

# Start TypeScript backend server in background
echo -e "${GREEN}Starting TypeScript backend server...${NC}"
cd typescript
node dist/server.js &
SERVER_PID=$!
cd ..

# Give server time to start
sleep 2

# Check if server started successfully
if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo -e "${RED}Failed to start TypeScript backend server${NC}"
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
flutter run

# When flutter exits, cleanup will automatically run
