import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:galaxi/src/backend/api.dart';
import 'package:galaxi/src/backend/dto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';
import 'library_page.dart';

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
