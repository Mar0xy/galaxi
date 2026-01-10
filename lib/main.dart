import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minigalaxy_flutter/src/rust/api/simple.dart';
import 'package:minigalaxy_flutter/src/rust/api/dto.dart';
import 'package:minigalaxy_flutter/src/rust/frb_generated.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const MinigalaxyApp());
}

class MinigalaxyApp extends StatefulWidget {
  const MinigalaxyApp({super.key});

  @override
  State<MinigalaxyApp> createState() => _MinigalaxyAppState();
}

class _MinigalaxyAppState extends State<MinigalaxyApp> {
  bool _darkTheme = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final dark = await getDarkTheme();
      setState(() {
        _darkTheme = dark;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _updateTheme(bool dark) {
    setState(() => _darkTheme = dark);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

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
      themeMode: _darkTheme ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(onThemeChanged: _updateTheme),
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(bool)? onThemeChanged;

  const HomePage({super.key, this.onThemeChanged});

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
      // First check if we have a stored active account with refresh token
      final activeAccount = await getActiveAccount();
      if (activeAccount != null && activeAccount.refreshToken.isNotEmpty) {
        // Try to authenticate using stored refresh token
        try {
          await authenticate(refreshToken: activeAccount.refreshToken);
          final userData = await getUserData();
          final accounts = await getAllAccounts();
          
          // Find the active account to get avatar URL
          final currentAccount = accounts.firstWhere(
            (a) => a.userId == activeAccount.userId,
            orElse: () => activeAccount,
          );
          
          setState(() {
            _isLoggedIn = true;
            _username = userData.username;
            _avatarUrl = currentAccount.avatarUrl;
            _accounts = accounts;
          });
        } catch (e) {
          // Refresh token might be expired, need to re-login
          setState(() {
            _isLoggedIn = false;
          });
        }
      } else {
        // Check if logged in (in case already authenticated this session)
        final loggedIn = await isLoggedIn();
        if (loggedIn) {
          final userData = await getUserData();
          final accounts = await getAllAccounts();
          
          // Try to get avatar from accounts
          String? avatarUrl;
          final matchingAccount = accounts.where((a) => a.username == userData.username).toList();
          if (matchingAccount.isNotEmpty) {
            avatarUrl = matchingAccount.first.avatarUrl;
          }
          
          setState(() {
            _isLoggedIn = true;
            _username = userData.username;
            _avatarUrl = avatarUrl;
            _accounts = accounts;
          });
        }
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
      onThemeChanged: widget.onThemeChanged,
      onAddAccount: () async {
        // Show login dialog to add another account
        await _showLoginDialog(context, isAddingAccount: true);
      },
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
  
  Future<void> _showLoginDialog(BuildContext context, {bool isAddingAccount = false}) async {
    final codeController = TextEditingController();
    final loginUrl = getLoginUrl();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSubmitting = false;
        String? errorMessage;
        
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(isAddingAccount ? 'Add GOG Account' : 'Login to GOG'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Click the button below to open the login page:'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(loginUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open GOG Login'),
                  ),
                  const SizedBox(height: 16),
                  const Text('2. Login with your GOG account'),
                  const SizedBox(height: 8),
                  const Text('3. After login, you\'ll be redirected to a blank page'),
                  const SizedBox(height: 8),
                  const Text('4. Copy the code from the URL (after "code=")'),
                  const SizedBox(height: 16),
                  const Text('5. Paste the code below:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      hintText: 'Paste authorization code here',
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        tooltip: 'Paste from clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            codeController.text = data!.text!;
                          }
                        },
                      ),
                    ),
                    autofocus: true,
                  ),
                  if (isSubmitting)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final code = codeController.text.trim();
                  if (code.isEmpty) {
                    setDialogState(() => errorMessage = 'Please enter the authorization code');
                    return;
                  }
                  
                  setDialogState(() {
                    isSubmitting = true;
                    errorMessage = null;
                  });
                  
                  try {
                    final refreshToken = await authenticate(loginCode: code);
                    await addCurrentAccount(refreshToken: refreshToken);
                    if (context.mounted) {
                      Navigator.pop(context, true); // Success
                    }
                  } catch (e) {
                    setDialogState(() {
                      isSubmitting = false;
                      errorMessage = 'Login failed: $e';
                    });
                  }
                },
                child: const Text('Login'),
              ),
            ],
          ),
        );
      },
    ).then((success) async {
      if (success == true) {
        await _checkLoginStatus();
      }
    });
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
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    
    final codeController = TextEditingController();
    final loginUrl = getLoginUrl();
    
    if (!mounted) {
      setState(() => _isLoading = false);
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSubmitting = false;
        String? errorMessage;
        
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Login to GOG'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Click the button below to open the login page:'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(loginUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open GOG Login'),
                  ),
                  const SizedBox(height: 16),
                  const Text('2. Login with your GOG account'),
                  const SizedBox(height: 8),
                  const Text('3. After login, you\'ll be redirected to a blank page'),
                  const SizedBox(height: 8),
                  const Text('4. Copy the code from the URL (after "code=")'),
                  const SizedBox(height: 16),
                  const Text('5. Paste the code below:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      hintText: 'Paste authorization code here',
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        tooltip: 'Paste from clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            codeController.text = data!.text!;
                          }
                        },
                      ),
                    ),
                    autofocus: true,
                  ),
                  if (isSubmitting)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () {
                  Navigator.pop(context, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final code = codeController.text.trim();
                  if (code.isEmpty) {
                    setDialogState(() => errorMessage = 'Please enter the authorization code');
                    return;
                  }
                  
                  setDialogState(() {
                    isSubmitting = true;
                    errorMessage = null;
                  });
                  
                  try {
                    final refreshToken = await authenticate(loginCode: code);
                    await addCurrentAccount(refreshToken: refreshToken);
                    if (context.mounted) {
                      Navigator.pop(context, true); // Success
                    }
                  } catch (e) {
                    setDialogState(() {
                      isSubmitting = false;
                      errorMessage = 'Login failed: $e';
                    });
                  }
                },
                child: const Text('Login'),
              ),
            ],
          ),
        );
      },
    ).then((success) {
      setState(() => _isLoading = false);
      if (success == true && mounted) {
        // Refresh the app state
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    });
  }
}

class LibraryPage extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final List<AccountDto> accounts;
  final VoidCallback onLogout;
  final VoidCallback? onAddAccount;
  final Function(bool)? onThemeChanged;

  const LibraryPage({
    super.key,
    required this.username,
    this.avatarUrl,
    required this.accounts,
    required this.onLogout,
    this.onAddAccount,
    this.onThemeChanged,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _isLoading = true;
  List<GameDto> _games = [];
  String _searchQuery = '';
  bool _showInstalledOnly = false;
  bool _showWindowsGames = false;
  String _viewMode = 'grid';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLibrary();
  }

  Future<void> _loadSettings() async {
    try {
      final mode = await getViewMode();
      final showWindows = await getShowWindowsGames();
      setState(() {
        _viewMode = mode;
        _showWindowsGames = showWindows;
      });
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
    
    // Filter out Windows games if not enabled
    if (!_showWindowsGames) {
      games = games.where((g) => g.platform.toLowerCase() != 'windows').toList();
    }
    
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
          // Trigger add account flow
          widget.onAddAccount?.call();
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
        onTap: () => _openGamePage(game),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background color for letterboxing
                  Container(color: Colors.grey[850] ?? Colors.grey[800]),
                  if (game.imageUrl.isNotEmpty)
                    Image.network(
                      'https:${game.imageUrl}_196.jpg',
                      fit: BoxFit.cover, // Cover to fill without empty space
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
              onPressed: () => _openGamePage(game),
            ),
          ],
        ),
        onTap: () => _openGamePage(game),
      ),
    );
  }

  void _openGamePage(GameDto game) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => GamePage(game: game),
      ),
    );
    // If installation happened, refresh just that game in the list
    if (result == true) {
      _refreshSingleGame(game.id);
    }
  }

  Future<void> _refreshSingleGame(int gameId) async {
    try {
      final games = await getLibrary();
      final index = _games.indexWhere((g) => g.id == gameId);
      if (index >= 0) {
        final updatedGame = games.firstWhere((g) => g.id == gameId, orElse: () => _games[index]);
        setState(() {
          _games[index] = updatedGame;
        });
      }
    } catch (e) {
      // Ignore errors, just refresh later
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onThemeChanged: widget.onThemeChanged,
          onWindowsGamesChanged: (value) {
            setState(() => _showWindowsGames = value);
          },
        ),
      ),
    );
  }
}

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
                applicationName: 'Minigalaxy',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 Minigalaxy Flutter',
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

/// Game detail page with background, description, and screenshots
class GamePage extends StatefulWidget {
  final GameDto game;

  const GamePage({super.key, required this.game});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  bool _isLoading = true;
  GameDto _game = GameDto(
    id: 0,
    name: '',
    url: '',
    installDir: '',
    imageUrl: '',
    platform: '',
    category: '',
    dlcs: [],
  );
  String? _backgroundUrl;
  String? _description;
  String? _summary;
  bool _installationCompleted = false;
  List<String> _screenshots = [];

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _loadGameDetails();
  }

  Future<void> _loadGameDetails() async {
    setState(() => _isLoading = true);
    try {
      // Try to get extended game info
      final gameInfo = await getGameInfo(gameId: widget.game.id);
      final gamesDbInfo = await getGamesdbInfo(gameId: widget.game.id);
      
      setState(() {
        if (gameInfo.description != null && gameInfo.description!.isNotEmpty) {
          _description = gameInfo.description;
        }
        if (gamesDbInfo.background.isNotEmpty) {
          _backgroundUrl = gamesDbInfo.background;
        }
        if (gamesDbInfo.summary.isNotEmpty) {
          _summary = gamesDbInfo.summary;
        }
        if (gameInfo.screenshots.isNotEmpty) {
          _screenshots = gameInfo.screenshots;
        }
      });
    } catch (e) {
      // Use default image as background if API fails
    }
    setState(() => _isLoading = false);
  }

  Future<void> _refreshGame() async {
    try {
      final games = await getLibrary();
      final updatedGame = games.firstWhere(
        (g) => g.id == widget.game.id,
        orElse: () => widget.game,
      );
      setState(() {
        _game = updatedGame;
        _installationCompleted = true;
      });
    } catch (e) {
      // Ignore
    }
  }

  void _showFullScreenshot(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Screenshot ${initialIndex + 1} of ${_screenshots.length}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: _screenshots.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: Center(
                  child: Image.network(
                    _screenshots[index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInstalled = _game.installDir.isNotEmpty;
    final backgroundImage = _backgroundUrl ?? 
        (widget.game.imageUrl.isNotEmpty 
            ? 'https:${widget.game.imageUrl}_glx_logo.jpg' 
            : null);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with background image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context, _installationCompleted),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.game.name,
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backgroundImage != null)
                    Image.network(
                      backgroundImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else
                    Container(color: Theme.of(context).colorScheme.primary),
                  // Gradient overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Platform and category chips
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(widget.game.platform),
                        avatar: Icon(
                          widget.game.platform.toLowerCase() == 'linux'
                              ? Icons.computer
                              : Icons.window,
                          size: 16,
                        ),
                      ),
                      Chip(label: Text(widget.game.category)),
                      if (isInstalled)
                        const Chip(
                          label: Text('Installed'),
                          backgroundColor: Colors.green,
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  if (isInstalled) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await launchGameAsync(gameId: widget.game.id);
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
                              minimumSize: const Size(0, 56),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Uninstall Game'),
                                content: Text('Are you sure you want to uninstall ${widget.game.name}?'),
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
                                await uninstallGame(gameId: widget.game.id);
                                if (mounted) {
                                  _refreshGame();
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
                            minimumSize: const Size(0, 56),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    _InstallButton(
                      gameId: widget.game.id,
                      gameName: widget.game.name,
                      onInstallComplete: () {
                        _refreshGame();
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Description section
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    if (_summary != null && _summary!.isNotEmpty) ...[
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _summary!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_description != null && _description!.isNotEmpty) ...[
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        // Strip HTML tags and clean up whitespace
                        _description!
                            .replaceAll(RegExp(r'<br\s*/?>'), '\n')
                            .replaceAll(RegExp(r'<p[^>]*>'), '\n')
                            .replaceAll(RegExp(r'</p>'), '\n')
                            .replaceAll(RegExp(r'<[^>]*>'), '')
                            .replaceAll('&nbsp;', ' ')
                            .replaceAll('&amp;', '&')
                            .replaceAll('&lt;', '<')
                            .replaceAll('&gt;', '>')
                            .replaceAll('&quot;', '"')
                            .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n') // Remove excess newlines
                            .trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    
                    // Screenshots section
                    if (_screenshots.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Text(
                        'Screenshots',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _screenshots.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < _screenshots.length - 1 ? 16 : 0,
                              ),
                              child: GestureDetector(
                                onTap: () => _showFullScreenshot(context, index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _screenshots[index],
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 320,
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image, size: 48),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    
                    // DLCs section
                    if (widget.game.dlcs.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Text(
                        'DLCs (${widget.game.dlcs.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ...widget.game.dlcs.map((dlc) => Card(
                        child: ListTile(
                          leading: dlc.imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    'https:${dlc.imageUrl}_100.jpg',
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.extension),
                                  ),
                                )
                              : const Icon(Icons.extension),
                          title: Text(dlc.name),
                          subtitle: Text(dlc.title),
                        ),
                      )),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stateful install button that shows download/install progress directly
class _InstallButton extends StatefulWidget {
  final int gameId;
  final String gameName;
  final VoidCallback? onInstallComplete;

  const _InstallButton({
    required this.gameId,
    required this.gameName,
    this.onInstallComplete,
  });

  @override
  State<_InstallButton> createState() => _InstallButtonState();
}

class _InstallButtonState extends State<_InstallButton> {
  String _status = 'idle'; // idle, downloading, installing, complete, error
  double _progress = 0.0;
  String? _errorMessage;

  Future<void> _startInstall() async {
    setState(() {
      _status = 'downloading';
      _progress = 0.0;
      _errorMessage = null;
    });

    try {
      // Start download and get installer path
      final installerPath = await startDownload(gameId: widget.gameId);
      
      // Give more time for download manager to start tracking progress
      await Future.delayed(const Duration(seconds: 1));
      
      // Poll for download progress
      bool downloadComplete = false;
      int nullProgressCount = 0;
      const maxNullCount = 60; // 30 seconds of null progress before giving up
      
      while (!downloadComplete) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          final progress = await getDownloadProgress(gameId: widget.gameId);
          if (progress != null) {
            nullProgressCount = 0;
            // Use toInt() for comparison since we might have BigInt or int
            final downloaded = progress.downloadedBytes is BigInt 
                ? (progress.downloadedBytes as BigInt).toInt() 
                : progress.downloadedBytes as int;
            final total = progress.totalBytes is BigInt 
                ? (progress.totalBytes as BigInt).toInt() 
                : progress.totalBytes as int;
            
            final percent = total > 0 ? downloaded / total : 0.0;
            setState(() {
              _progress = percent;
            });
            
            if (progress.status == 'Completed') {
              downloadComplete = true;
            } else if (progress.status == 'Failed') {
              throw Exception('Download failed');
            } else if (progress.status == 'Cancelled') {
              throw Exception('Download cancelled');
            }
          } else {
            // Progress is null - download either hasn't started or has finished
            nullProgressCount++;
            // Only assume complete if we've seen some progress before
            // (null at the very start means download hasn't begun yet)
            if (nullProgressCount > maxNullCount) {
              throw Exception('Download timed out - no progress received');
            }
          }
        } catch (e) {
          // If getting progress fails, continue polling
          nullProgressCount++;
          if (nullProgressCount > maxNullCount) {
            throw Exception('Failed to get download progress: $e');
          }
        }
      }
      
      // Now install
      setState(() {
        _status = 'installing';
        _progress = 1.0;
      });
      
      // Install using the returned installer path
      await installGame(
        gameId: widget.gameId,
        installerPath: installerPath,
      );
      
      setState(() {
        _status = 'complete';
      });
      
      await Future.delayed(const Duration(seconds: 1));
      widget.onInstallComplete?.call();
      
    } catch (e) {
      setState(() {
        _status = 'error';
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case 'downloading':
        return Column(
          children: [
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: null,
              icon: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text('Downloading... ${(_progress * 100).toStringAsFixed(0)}%'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        );
      case 'installing':
        return ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('Installing...'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        );
      case 'complete':
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check, color: Colors.green),
          label: const Text('Installed!'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        );
      case 'error':
        return Column(
          children: [
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _startInstall,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Install'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        );
      default:
        return ElevatedButton.icon(
          onPressed: _startInstall,
          icon: const Icon(Icons.download),
          label: const Text('Install'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        );
    }
  }
}
