# Galaxi TypeScript Backend

This is the TypeScript/Node.js backend for the Galaxi GOG client, replacing the previous Rust implementation.

## Prerequisites

- Node.js 18+ and npm
- TypeScript 5.3+

## Installation

```bash
cd typescript
npm install
```

## Building

```bash
cd typescript
npm run build
```

## Running the Backend Server

The backend runs as an HTTP server that Flutter communicates with via REST API.

```bash
cd typescript
npm start
```

The server will start on `http://localhost:3000` by default.

## Development

For development with auto-reload:

```bash
cd typescript
npm run dev
```

## Running the Flutter App

1. First, start the TypeScript backend server:
   ```bash
   cd typescript
   npm start
   ```

2. In a separate terminal, run the Flutter app:
   ```bash
   flutter pub get
   flutter run
   ```

## Architecture

The TypeScript backend provides the same API as the previous Rust implementation:

- **Authentication**: GOG OAuth login flow
- **Library Management**: Fetch and manage game library
- **Game Installation**: Download and install games
- **Game Launching**: Launch games with Wine support
- **Configuration**: App settings and preferences
- **Database**: SQLite for local data storage

## API Communication

Flutter communicates with the TypeScript backend via HTTP POST requests to `http://localhost:3000`. Each request contains:

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

## Converting from Rust

The conversion from Rust to TypeScript involved:

1. Converting all Rust source files in `rust/src/api/` to TypeScript in `typescript/src/api/`
2. Replacing Rust dependencies (reqwest, tokio, rusqlite) with TypeScript equivalents (axios, better-sqlite3)
3. Creating an HTTP server for Flutter communication
4. Updating Flutter code to use HTTP client instead of flutter_rust_bridge

## Dependencies

Key TypeScript/Node.js dependencies:

- **axios**: HTTP client for GOG API calls
- **better-sqlite3**: SQLite database for local storage
- **md5**: File checksums
- **typescript**: TypeScript compiler

## Future Improvements

- Implement method channels for more efficient communication
- Add WebSocket support for real-time updates
- Complete all TODO items in the implementation
- Add comprehensive error handling
- Add logging and debugging capabilities
