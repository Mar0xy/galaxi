# Building Galaxi Backend Executable

The Galaxi backend can be bundled into a standalone executable using Bun's compiler. This eliminates the need for users to install Node.js or Bun.

## Prerequisites

Install Bun: https://bun.sh
```bash
curl -fsSL https://bun.sh/install | bash
```

## Build Commands

### Build for Linux (x64)
```bash
cd typescript
bun install  # Install dependencies first
bun run build
```

This creates `galaxi-backend` executable for Linux x64 in the current directory.

## Running the Executable

The standalone executable includes:
- All TypeScript/JavaScript code
- Native dependencies (better-sqlite3)
- Bun runtime

Simply run it:
```bash
./galaxi-backend
```

The server will start on port 3000.

## Distribution

The `galaxi-backend` executable is self-contained for Linux x64 users. Users won't need to install Node.js, Bun, or any dependencies!

## CI/CD

The executable is automatically built in the GitHub Actions workflow and included in the Linux release package.

## Notes

- The executable is self-contained but platform-specific (Linux x64 only)
- The executable size will be ~50-80MB due to embedded Bun runtime
- Better-sqlite3 native bindings are automatically bundled
- The executable is built during CI and packaged with the Flutter app
