import 'package:flutter/material.dart';
import 'package:galaxi/src/backend/api.dart';
import 'package:galaxi/src/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Note: Backend server must be started separately
  runApp(const GalaxiApp());
}

class GalaxiApp extends StatefulWidget {
  const GalaxiApp({super.key});

  @override
  State<GalaxiApp> createState() => _GalaxiAppState();
}

class _GalaxiAppState extends State<GalaxiApp> {
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
      title: 'Galaxi',
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
