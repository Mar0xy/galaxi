import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:galaxi/src/backend/api.dart';
import 'package:galaxi/src/backend/dto.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:galaxi/src/widgets/install_button.dart';

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
  bool _isGameRunning = false;
  int _playtime = 0;
  int _totalPlaytimeFromDb = 0;
  Timer? _playtimeTimer;

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _loadGameDetails();
    _checkGameRunning();
  }
  
  @override
  void dispose() {
    _playtimeTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _checkGameRunning() async {
    try {
      // Always load total playtime from database first
      final totalPlaytime = await getTotalGamePlaytime(widget.game.id);
      final running = await isGameRunning(widget.game.id);
      
      if (mounted) {
        setState(() {
          _totalPlaytimeFromDb = totalPlaytime;
          _playtime = totalPlaytime;
          _isGameRunning = running;
        });
      }
      
      if (running) {
        _startPlaytimeTracking();
      }
    } catch (e) {
      // Ignore error
    }
  }
  
  void _startPlaytimeTracking() {
    _playtimeTimer?.cancel();
    _playtimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final running = await isGameRunning(widget.game.id);
        final currentSessionPlaytime = await getGamePlaytime(widget.game.id);
        
        if (mounted) {
          setState(() {
            _isGameRunning = running;
            // Show total time = database total + current session
            _playtime = _totalPlaytimeFromDb + currentSessionPlaytime;
          });
        }
        
        if (!running) {
          timer.cancel();
          // Wait a moment for backend to save playtime to database, then reload
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            final updatedTotal = await getTotalGamePlaytime(widget.game.id);
            setState(() {
              _totalPlaytimeFromDb = updatedTotal;
              _playtime = updatedTotal;
              _isGameRunning = false;
            });
          }
        }
      } catch (e) {
        timer.cancel();
      }
    });
  }
  
  String _formatPlaytime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
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
                  child: CachedNetworkImage(
                    imageUrl: _screenshots[index],
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Icon(
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
                    CachedNetworkImage(
                      imageUrl: backgroundImage,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      errorWidget: (context, url, error) => Container(
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
                  // Playtime counter overlay (top right)
                  if (_playtime > 0)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatPlaytime(_playtime),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                            onPressed: _isGameRunning ? null : () async {
                              try {
                                await launchGameAsync(gameId: widget.game.id);
                                // Start tracking playtime after launch
                                _checkGameRunning();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to launch: $e')),
                                  );
                                }
                              }
                            },
                            icon: Icon(_isGameRunning ? Icons.videogame_asset : Icons.play_arrow),
                            label: Text(_isGameRunning ? 'Playing' : 'Play'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 56),
                              backgroundColor: _isGameRunning ? Colors.orange : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        if (!_isGameRunning) ...[
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
                      ],
                    ),
                  ] else ...[
                    InstallButton(
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
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) => true, // Absorb scroll notifications
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: {
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.touch,
                                PointerDeviceKind.stylus,
                                PointerDeviceKind.trackpad,
                              },
                            ),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              itemCount: _screenshots.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final screenshot = _screenshots[index];
                                return GestureDetector(
                                  onTap: () => _showFullScreenshot(context, index),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: screenshot,
                                      height: 200,
                                      width: 320,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 320,
                                        height: 200,
                                        color: Colors.grey[800],
                                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 320,
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image, size: 48),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
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
                                  child: CachedNetworkImage(
                                    imageUrl: 'https:${dlc.imageUrl}_100.jpg',
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey[800],
                                    ),
                                    errorWidget: (context, url, error) => const Icon(Icons.extension),
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
