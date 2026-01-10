# Galaxi

A GOG Galaxy client for Linux built with Flutter (UI) and TypeScript (backend).

## Features

- **Authentication**: Login to GOG via browser-based OAuth flow
- **Library Management**: View your GOG game library with grid/list views, search, and filtering
- **Game Installation**: Download and install games with progress tracking, resume interrupted downloads
- **Wine Integration**: Automatic Wine prefix creation with winetricks (dxvk, vkd3d, corefonts)
- **Game Launching**: Launch Windows games via Wine with per-game prefix support
- **Multi-Account**: Support for multiple GOG accounts with easy switching
- **Offline Caching**: Network images cached locally for faster loading
- **Dark/Light Theme**: Toggle between dark and light themes

## Wine Settings

- Global wine executable configuration (wine, wine64, proton, etc.)
- Per-game Wine prefixes stored in `{game_dir}/wine_prefix`
- NTSYNC disable option (`WINE_DISABLE_FAST_SYNC=1`) for compatibility
- Auto-install DXVK/VKD3D via winetricks

## Building

### Prerequisites

- Flutter 3.27+
- Node.js 18+ and npm
- Linux development dependencies (GTK3, etc.)

### Build Steps

```bash
# Install TypeScript dependencies
cd typescript
npm install
npm run build
cd ..

# Install Flutter dependencies
flutter pub get

# Build release
flutter build linux --release
```

The built application will be in `build/linux/x64/release/bundle/`.

## Running

The easiest way to run Galaxi is using the combined startup script:

```bash
./start-galaxi.sh
```

This script will:
1. Start the TypeScript backend server on http://localhost:3000
2. Launch the Flutter app
3. Automatically stop the backend server when the app exits

### Manual Running

If you prefer to run the components separately:

**Terminal 1 - Start TypeScript Backend:**
```bash
cd typescript
npm start
```

**Terminal 2 - Start Flutter App:**
```bash
flutter run
```

## Usage

1. Launch the application
2. Click "Login to GOG" to authenticate
3. Copy the code from the browser URL after login
4. Paste the code into the dialog and click "Login"
5. Browse your library and install games

## Architecture

Galaxi uses a client-server architecture:
- **Frontend**: Flutter app providing the UI
- **Backend**: TypeScript/Node.js server handling GOG API, game management, downloads, and Wine integration
- **Communication**: HTTP REST API between Flutter and TypeScript backend

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [Minigalaxy](https://github.com/sharkwouter/minigalaxy)
- Originally built with Rust backend using [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge)
- Converted to TypeScript backend for improved accessibility and maintainability
