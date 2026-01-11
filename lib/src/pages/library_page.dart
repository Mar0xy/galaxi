import 'package:flutter/material.dart';
import 'package:galaxi/src/backend/api.dart';
import 'package:galaxi/src/backend/dto.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'settings_page.dart';
import 'game_page.dart';

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
      // Fetch library from API (this also populates the cache)
      await getLibrary();
      // Scan for games that were installed before but not tracked in the database
      await scanForInstalledGames();
      // Get updated games from cache (includes updated install_dir values)
      final updatedGames = await getCachedGames();
      setState(() => _games = updatedGames);
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
        title: const Text('Galaxi'),
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
            ? CachedNetworkImageProvider(widget.avatarUrl!)
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
                      ? CachedNetworkImageProvider(account.avatarUrl!)
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
                    Center(
                      child: CachedNetworkImage(
                        imageUrl: 'https:${game.imageUrl}_196.jpg',
                        fit: BoxFit.cover, // Cover to fill the space
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.games, size: 48),
                        ),
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
              ? CachedNetworkImage(
                  imageUrl: 'https:${game.imageUrl}_196.jpg',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[800],
                  ),
                  errorWidget: (context, url, error) => Container(
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
