import 'package:flutter/material.dart';
import 'package:minigalaxy_flutter/src/rust/api/simple.dart';
import 'package:minigalaxy_flutter/src/rust/api/dto.dart';
import 'package:minigalaxy_flutter/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MinigalaxyApp());
}

class MinigalaxyApp extends StatelessWidget {
  const MinigalaxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minigalaxy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String _username = '';
  String? _avatarUrl;
  List<AccountDto> _accounts = [];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    setState(() => _isLoading = true);
    try {
      final loggedIn = await isLoggedIn();
      if (loggedIn) {
        final userData = await getUserData();
        final accounts = await getAllAccounts();
        setState(() {
          _isLoggedIn = true;
          _username = userData.username;
          _accounts = accounts;
        });
      }
    } catch (e) {
      // Not logged in or error
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isLoggedIn) {
      return const LoginPage();
    }

    return LibraryPage(
      username: _username,
      avatarUrl: _avatarUrl,
      accounts: _accounts,
      onLogout: () async {
        await logout();
        setState(() {
          _isLoggedIn = false;
          _username = '';
          _avatarUrl = null;
        });
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.games,
              size: 100,
              color: Colors.purple,
            ),
            const SizedBox(height: 24),
            const Text(
              'Minigalaxy',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A simple GOG client for Linux',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _login,
                icon: const Icon(Icons.login),
                label: const Text('Login with GOG'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Login URL:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              getLoginUrl(),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    // In a real app, you would open a webview and handle OAuth
    // For now, show a dialog explaining how to login
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Instructions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Open this URL in a browser:'),
            const SizedBox(height: 8),
            SelectableText(
              getLoginUrl(),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text('2. Login with your GOG account'),
            const SizedBox(height: 8),
            const Text('3. Copy the code from the redirect URL'),
            const SizedBox(height: 8),
            const Text('4. Enter the code below'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    setState(() => _isLoading = false);
  }
}

class LibraryPage extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final List<AccountDto> accounts;
  final VoidCallback onLogout;

  const LibraryPage({
    super.key,
    required this.username,
    this.avatarUrl,
    required this.accounts,
    required this.onLogout,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _isLoading = true;
  List<GameDto> _games = [];
  String _searchQuery = '';
  bool _showInstalledOnly = false;
  String _viewMode = 'grid';

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    try {
      final mode = await getViewMode();
      setState(() => _viewMode = mode);
    } catch (e) {
      // Use default
    }
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);
    try {
      final games = await getLibrary();
      setState(() => _games = games);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load library: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  List<GameDto> get _filteredGames {
    var games = _games;
    if (_searchQuery.isNotEmpty) {
      games = games.where((g) => 
        g.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    if (_showInstalledOnly) {
      games = games.where((g) => g.installDir.isNotEmpty).toList();
    }
    return games;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minigalaxy'),
        actions: [
          IconButton(
            icon: Icon(_viewMode == 'grid' ? Icons.grid_view : Icons.list),
            onPressed: () async {
              final newMode = _viewMode == 'grid' ? 'list' : 'grid';
              await setViewMode(view: newMode);
              setState(() => _viewMode = newMode);
            },
            tooltip: 'Toggle view',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLibrary,
            tooltip: 'Refresh library',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
          _buildAccountMenu(),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildGamesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountMenu() {
    return PopupMenuButton<String>(
      icon: CircleAvatar(
        backgroundImage: widget.avatarUrl != null
            ? NetworkImage(widget.avatarUrl!)
            : null,
        child: widget.avatarUrl == null
            ? Text(widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?')
            : null,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            'Logged in as ${widget.username}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const PopupMenuDivider(),
        if (widget.accounts.length > 1) ...[
          const PopupMenuItem(
            enabled: false,
            child: Text('Switch Account:'),
          ),
          ...widget.accounts.map((account) => PopupMenuItem(
            value: 'switch:${account.userId}',
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: account.avatarUrl != null
                      ? NetworkImage(account.avatarUrl!)
                      : null,
                  child: account.avatarUrl == null
                      ? Text(account.username[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 8),
                Text(account.username),
              ],
            ),
          )),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'add_account',
          child: Row(
            children: [
              Icon(Icons.add),
              SizedBox(width: 8),
              Text('Add Account'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'logout') {
          widget.onLogout();
        } else if (value == 'add_account') {
          // Show add account dialog
        } else if (value.startsWith('switch:')) {
          final userId = value.substring(7);
          await switchAccount(userId: userId);
          // Refresh the page
        }
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search games...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: const Text('Installed'),
            selected: _showInstalledOnly,
            onSelected: (value) => setState(() => _showInstalledOnly = value),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList() {
    final games = _filteredGames;
    
    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.games_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No games found matching "$_searchQuery"'
                  : 'No games in your library',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_viewMode == 'grid') {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: games.length,
        itemBuilder: (context, index) => _buildGameCard(games[index]),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: games.length,
        itemBuilder: (context, index) => _buildGameListTile(games[index]),
      );
    }
  }

  Widget _buildGameCard(GameDto game) {
    final isInstalled = game.installDir.isNotEmpty;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showGameDetails(game),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (game.imageUrl.isNotEmpty)
                    Image.network(
                      'https:${game.imageUrl}_196.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.games, size: 48),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.games, size: 48),
                    ),
                  if (isInstalled)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Installed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                game.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameListTile(GameDto game) {
    final isInstalled = game.installDir.isNotEmpty;
    
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: game.imageUrl.isNotEmpty
              ? Image.network(
                  'https:${game.imageUrl}_196.jpg',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[300],
                    child: const Icon(Icons.games),
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[300],
                  child: const Icon(Icons.games),
                ),
        ),
        title: Text(game.name),
        subtitle: Text(game.platform),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isInstalled)
              const Chip(
                label: Text('Installed'),
                backgroundColor: Colors.green,
                labelStyle: TextStyle(color: Colors.white, fontSize: 10),
              ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showGameDetails(game),
            ),
          ],
        ),
        onTap: () => _showGameDetails(game),
      ),
    );
  }

  void _showGameDetails(GameDto game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                if (game.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https:${game.imageUrl}_392.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(Icons.games, size: 64),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Chip(label: Text(game.platform)),
                    const SizedBox(width: 8),
                    Chip(label: Text(game.category)),
                  ],
                ),
                const SizedBox(height: 24),
                if (game.installDir.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await launchGameAsync(gameId: game.id);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to launch: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Uninstall Game'),
                          content: Text('Are you sure you want to uninstall ${game.name}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Uninstall'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await uninstallGame(gameId: game.id);
                          if (mounted) {
                            Navigator.pop(context);
                            _loadLibrary();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to uninstall: $e')),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Uninstall'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await startDownload(gameId: game.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Download started')),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to download: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Install'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _installDir = '';
  String _language = 'en';
  bool _darkTheme = false;
  bool _showWindowsGames = false;
  bool _keepInstallers = false;

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
      setState(() {
        _installDir = installDir;
        _language = language;
        _darkTheme = darkTheme;
        _showWindowsGames = showWindows;
        _keepInstallers = keepInstallers;
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
                    onPressed: () => Navigator.pop(context, lang.$1),
                    child: Text(lang.$2),
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
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Minigalaxy',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 Minigalaxy Flutter',
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'A simple GOG client for Linux, macOS, and Windows.\n\n'
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
}
