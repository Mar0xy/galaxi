# Galaxi

A GOG Galaxy client for Linux built with Flutter (UI) and Rust (backend), connected via flutter_rust_bridge.

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

- Flutter 3.5+
- Rust 1.70+
- Linux development dependencies (GTK3, etc.)

### Build Steps

```bash
# Install dependencies
flutter pub get

# Generate Rust bridge bindings
flutter_rust_bridge_codegen generate

# Build release
flutter build linux --release
```

The built application will be in `build/linux/x64/release/bundle/`.

## Usage

1. Launch the application
2. Click "Login to GOG" to authenticate
3. Copy the code from the browser URL after login
4. Paste the code into the dialog and click "Login"
5. Browse your library and install games

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [Minigalaxy](https://github.com/sharkwouter/minigalaxy)
- Uses [flutter_rust_bridge](https://github.com/aspect-dev/flutter_rust_bridge) for Rust-Flutter interop
