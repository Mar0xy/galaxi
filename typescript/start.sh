#!/bin/bash

# Galaxi Backend Startup Script (Bun)

set -e

echo "Starting Galaxi Backend..."

# Change to the typescript directory
cd "$(dirname "$0")"

# Check if Bun is installed
if ! command -v bun &> /dev/null; then
    echo "Error: Bun is not installed. Please install Bun from https://bun.sh"
    echo "Quick install: curl -fsSL https://bun.sh/install | bash"
    exit 1
fi

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    bun install
fi

# Start the server
echo "Starting server on http://localhost:3000"
bun run start
