import 'package:flutter/material.dart';
import 'package:galaxi/src/backend/api.dart';

class SettingsPage extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  final Function(bool)? onWindowsGamesChanged;

  const SettingsPage({
    super.key,
    this.onThemeChanged,
    this.onWindowsGamesChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _appVersion = '1.0.0';
  static const int _copyrightYear = 2026;
  
  String _installDir = '';
  String _language = 'en';
  bool _darkTheme = false;
  bool _showWindowsGames = false;
  bool _keepInstallers = false;
  String _winePrefix = '';
  String _wineExecutable = '';
  bool _wineDebug = false;
  bool _wineDisableNtsync = false;
  bool _wineAutoInstallDxvk = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final installDir = await getInstallDir();
      final language = await getLanguage();
      final darkTheme = await getDarkTheme();
      final showWindows = await getShowWindowsGames();
      final keepInstallers = await getKeepInstallers();
      final winePrefix = await getWinePrefix();
      final wineExecutable = await getWineExecutable();
      final wineDebug = await getWineDebug();
      final wineDisableNtsync = await getWineDisableNtsync();
      final wineAutoInstallDxvk = await getWineAutoInstallDxvk();
      setState(() {
        _installDir = installDir;
        _language = language;
        _darkTheme = darkTheme;
        _showWindowsGames = showWindows;
        _keepInstallers = keepInstallers;
        _winePrefix = winePrefix;
        _wineExecutable = wineExecutable;
        _wineDebug = wineDebug;
        _wineDisableNtsync = wineDisableNtsync;
        _wineAutoInstallDxvk = wineAutoInstallDxvk;
      });
    } catch (e) {
      // Use defaults
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Install Directory'),
            subtitle: Text(_installDir),
            onTap: () async {
              // Show dialog to change install directory
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Download Language'),
            subtitle: Text(_language),
            onTap: () async {
              final languages = getSupportedLanguages();
              final selected = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Select Language'),
                  children: languages.map((lang) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, lang['code']),
                    child: Text(lang['name']!),
                  )).toList(),
                ),
              );
              if (selected != null) {
                await setLanguage(lang: selected);
                setState(() => _language = selected);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Theme'),
            value: _darkTheme,
            onChanged: (value) async {
              await setDarkTheme(enabled: value);
              setState(() => _darkTheme = value);
              widget.onThemeChanged?.call(value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.window),
            title: const Text('Show Windows Games'),
            subtitle: const Text('Requires Wine'),
            value: _showWindowsGames,
            onChanged: (value) async {
              await setShowWindowsGames(enabled: value);
              setState(() => _showWindowsGames = value);
              widget.onWindowsGamesChanged?.call(value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save),
            title: const Text('Keep Installers'),
            subtitle: const Text('Keep installer files after installation'),
            value: _keepInstallers,
            onChanged: (value) async {
              await setKeepInstallers(enabled: value);
              setState(() => _keepInstallers = value);
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Wine Settings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wine_bar),
            title: const Text('Wine Prefix'),
            subtitle: Text(_winePrefix.isEmpty ? 'Default (~/.wine)' : _winePrefix),
            onTap: _selectWinePrefix,
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Wine Executable'),
            subtitle: Text(_wineExecutable.isEmpty ? 'System default (wine)' : _wineExecutable),
            onTap: _selectWineExecutable,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bug_report),
            title: const Text('Wine Debug Mode'),
            subtitle: const Text('Show Wine debug output'),
            value: _wineDebug,
            onChanged: (value) async {
              await setWineDebug(enabled: value);
              setState(() => _wineDebug = value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sync_disabled),
            title: const Text('Disable NTSYNC'),
            subtitle: const Text('Set WINE_DISABLE_FAST_SYNC=1 to fix /dev/ntsync errors'),
            value: _wineDisableNtsync,
            onChanged: (value) async {
              await setWineDisableNtsync(enabled: value);
              setState(() => _wineDisableNtsync = value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_fix_high),
            title: const Text('Auto-install DXVK/VKD3D'),
            subtitle: const Text('Install DXVK, VKD3D and fonts via winetricks'),
            value: _wineAutoInstallDxvk,
            onChanged: (value) async {
              await setWineAutoInstallDxvk(enabled: value);
              setState(() => _wineAutoInstallDxvk = value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_applications),
            title: const Text('Open Wine Configuration'),
            subtitle: const Text('Configure Wine settings'),
            onTap: () async {
              try {
                await openWineConfigGlobal();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wine configuration opened')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to open Wine config: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('Open Winetricks'),
            subtitle: const Text('Install Windows components'),
            onTap: () async {
              try {
                await openWinetricksGlobal();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Winetricks opened')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to open Winetricks: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Galaxi',
                applicationVersion: _appVersion,
                applicationLegalese: '© $_copyrightYear Galaxi',
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'A simple GOG client for Linux.\n\n'
                    'Built with Flutter and Rust.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectWinePrefix() async {
    final controller = TextEditingController(text: _winePrefix);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wine Prefix'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the path to your Wine prefix, or leave empty for default.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '~/.wine',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await setWinePrefix(prefix: result);
      setState(() => _winePrefix = result);
    }
  }

  Future<void> _selectWineExecutable() async {
    final controller = TextEditingController(text: _wineExecutable);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wine Executable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the path to your Wine executable, or leave empty for system default.'),
            const SizedBox(height: 8),
            const Text(
              'Examples: wine, wine64, /opt/wine-staging/bin/wine, proton',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'wine',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await setWineExecutable(executable: result);
      setState(() => _wineExecutable = result);
    }
  }
}
