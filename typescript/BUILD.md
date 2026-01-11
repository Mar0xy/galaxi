# Building Galaxi Backend Executable

The Galaxi backend can be bundled into a standalone executable using Bun's compiler. This eliminates the need for users to install Node.js or Bun.

## Prerequisites

Install Bun: https://bun.sh
```bash
curl -fsSL https://bun.sh/install | bash
```

## Build Commands

### Build for Current Platform
```bash
cd typescript
bun install  # Install dependencies first
bun run build
```

This creates `galaxi-backend` executable in the current directory.

### Build for Specific Platforms

**Linux (x64):**
```bash
bun run build:linux
```
Creates: `galaxi-backend-linux`

**macOS (x64):**
```bash
bun run build:macos
```
Creates: `galaxi-backend-macos`

**Windows (x64):**
```bash
bun run build:windows
```
Creates: `galaxi-backend-windows.exe`

## Running the Executable

The standalone executable includes:
- All TypeScript/JavaScript code
- Native dependencies (better-sqlite3)
- Bun runtime

Simply run it:
```bash
./galaxi-backend        # Linux/macOS
galaxi-backend.exe      # Windows
```

The server will start on port 3000.

## Distribution

Distribute the appropriate executable for each platform:
- `galaxi-backend-linux` for Linux users
- `galaxi-backend-macos` for macOS users  
- `galaxi-backend-windows.exe` for Windows users

Users won't need to install Node.js, Bun, or any dependencies!

## Notes

- The executable is self-contained but platform-specific
- Cross-compilation is supported (build Windows executable on Linux, etc.)
- The executable size will be ~50-80MB due to embedded Bun runtime
- Better-sqlite3 native bindings are automatically bundled
