#!/bin/bash

# Galaxi TypeScript Backend Startup Script

set -e

echo "Starting Galaxi TypeScript Backend..."

# Change to the typescript directory
cd "$(dirname "$0")"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Check if dist directory exists
if [ ! -d "dist" ]; then
    echo "Building TypeScript..."
    npm run build
fi

# Start the server
echo "Starting server on http://localhost:3000"
npm start
