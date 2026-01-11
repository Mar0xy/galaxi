# Galaxi Backend (TypeScript/Bun)

This is the TypeScript/Bun backend for the Galaxi GOG client, replacing the previous Rust implementation.

## Prerequisites

- **Bun** 1.0+ (https://bun.sh)
  - Fast JavaScript runtime with built-in TypeScript support
  - No need for Node.js or separate TypeScript installation

## Installation

```bash
cd typescript
bun install
```

## Running the Backend Server

The backend runs as an HTTP server that Flutter communicates with via REST API.

### Option 1: Run with Bun (Development)

```bash
cd typescript
bun run start
```

### Option 2: Run with Auto-reload (Development)

```bash
cd typescript
bun run dev
```

### Option 3: Build Standalone Executable (Production)

Build a self-contained executable for Linux x64 that includes all dependencies and the Bun runtime:

```bash
cd typescript
bun run build
```

This creates a `galaxi-backend` executable that users can run without installing Bun or any dependencies:

```bash
./galaxi-backend
```

See [BUILD.md](./BUILD.md) for detailed build instructions.

The server will start on `http://localhost:3000` by default.

## Running the Flutter App

Use the convenient startup script that automatically handles the backend:

```bash
./start-galaxi.sh
```

Or manually:

1. Start the backend server:
   ```bash
   cd typescript
   bun run start
   # OR use the standalone executable:
   ./galaxi-backend
   ```

2. In a separate terminal, run the Flutter app:
   ```bash
   flutter pub get
   flutter run
   ```

## Architecture

The TypeScript/Bun backend provides the same API as the previous Rust implementation:

- **Authentication**: GOG OAuth login flow
- **Library Management**: Fetch and manage game library
- **Game Installation**: Download and install games with Wine support
- **Game Launching**: Launch games with executable detection
- **Game Session Tracking**: Track running games and playtime
- **Playtime Persistence**: Store and accumulate playtime in SQLite database
- **Configuration**: App settings and preferences
- **Database**: SQLite for local data storage (games, playtime, config)

## API Communication

Flutter communicates with the backend via HTTP POST requests to `http://localhost:3000`. Each request contains:

```json
{
  "method": "methodName",
  "params": [param1, param2, ...]
}
```

Response format:

```json
{
  "success": true,
  "result": <return value>
}
```

Or on error:

```json
{
  "success": false,
  "error": "error message"
}
```

## Advantages of Bun

- **Fast**: Bun is significantly faster than Node.js for startup and runtime
- **TypeScript Native**: No compilation step needed for development
- **Built-in Bundler**: Create standalone executables with `bun build --compile`
- **Compatible**: Works with npm packages (axios, better-sqlite3)
- **Smaller Footprint**: Executables are more compact than Node.js alternatives

## Dependencies

Key dependencies:

- **axios**: HTTP client for GOG API calls
- **md5**: File checksums for downloads

All dependencies are bundled into the standalone executable when using `bun build --compile`.

## Distribution

For end users, distribute the standalone executable:

1. Build the executable: `bun run build`
2. Distribute `galaxi-backend` (Linux/macOS) or `galaxi-backend.exe` (Windows)
3. Users can run it directly without installing Bun, Node.js, or any dependencies

See [BUILD.md](./BUILD.md) for building executables for different platforms.

## Converting from Rust

The conversion from Rust to TypeScript involved:

1. Converting all Rust source files in `rust/src/api/` to TypeScript in `typescript/src/api/`
2. Replacing Rust dependencies (reqwest, tokio, rusqlite) with TypeScript equivalents (axios, better-sqlite3)
3. Creating an HTTP server for Flutter communication
4. Updating Flutter code to use HTTP client instead of flutter_rust_bridge
5. Adding game session tracking and playtime persistence
6. Migrating to Bun for better performance and standalone executable support
