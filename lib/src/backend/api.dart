import 'dart:convert';
import 'client.dart';
import 'dto.dart';

// Simple API functions
Future<String> greet(String name) async {
  return await backendClient.call<String>('greet', [name]);
}

// Authentication API
String getLoginUrl() {
  // This is a sync function, so we'll return the value directly
  // In the real implementation, the Flutter app can construct this URL
  const clientId = '46899977096215655';
  const redirectUri = 'https://embed.gog.com/on_login_success?origin=client';
  return 'https://auth.gog.com/auth?client_id=$clientId&redirect_uri=${Uri.encodeComponent(redirectUri)}&response_type=code&layout=client2';
}

String getRedirectUrl() {
  return 'https://embed.gog.com/on_login_success?origin=client';
}

String getSuccessUrl() {
  return 'https://embed.gog.com/on_login_success';
}

Future<String> authenticate({String? loginCode, String? refreshToken}) async {
  return await backendClient.call<String>('authenticate', [loginCode, refreshToken]);
}

Future<AccountDto> loginWithCode(String code) async {
  final result = await backendClient.call<Map<String, dynamic>>('loginWithCode', [code]);
  return AccountDto.fromJson(result);
}

Future<bool> isLoggedIn() async {
  return await backendClient.call<bool>('isLoggedIn');
}

Future<void> logout() async {
  await backendClient.call<void>('logout');
}

Future<UserDataDto> getUserData() async {
  final result = await backendClient.call<Map<String, dynamic>>('getUserData');
  return UserDataDto.fromJson(result);
}

// Account Management API
Future<List<AccountDto>> getAllAccounts() async {
  final result = await backendClient.call<List<dynamic>>('getAllAccounts');
  return result.map((e) => AccountDto.fromJson(e as Map<String, dynamic>)).toList();
}

Future<AccountDto?> getActiveAccount() async {
  final result = await backendClient.call<Map<String, dynamic>?>('getActiveAccount');
  return result != null ? AccountDto.fromJson(result) : null;
}

Future<AccountDto> addCurrentAccount(String refreshToken) async {
  final result = await backendClient.call<Map<String, dynamic>>('addCurrentAccount', [refreshToken]);
  return AccountDto.fromJson(result);
}

Future<bool> switchAccount(String userId) async {
  return await backendClient.call<bool>('switchAccount', [userId]);
}

Future<void> removeAccount(String userId) async {
  await backendClient.call<void>('removeAccount', [userId]);
}

// Library API
Future<List<GameDto>> getLibrary() async {
  final result = await backendClient.call<List<dynamic>>('getLibrary');
  return result.map((e) => GameDto.fromJson(e as Map<String, dynamic>)).toList();
}

// Config API
Future<ConfigDto> getConfig() async {
  final result = await backendClient.call<Map<String, dynamic>>('getConfig');
  return ConfigDto.fromJson(result);
}

Future<void> setConfigValue(String key, String value) async {
  await backendClient.call<void>('setConfigValue', [key, value]);
}

Future<bool> getDarkTheme() async {
  return await backendClient.call<bool>('getDarkTheme');
}

Future<void> setDarkTheme(bool value) async {
  await backendClient.call<void>('setDarkTheme', [value]);
}

// Additional Configuration API
Future<String> getInstallDir() async {
  return await backendClient.call<String>('getInstallDir');
}

Future<void> setInstallDir(String dir) async {
  await backendClient.call<void>('setInstallDir', [dir]);
}

Future<String> getLanguage() async {
  return await backendClient.call<String>('getLanguage');
}

Future<void> setLanguage(String lang) async {
  await backendClient.call<void>('setLanguage', [lang]);
}

Future<String> getViewMode() async {
  return await backendClient.call<String>('getViewMode');
}

Future<void> setViewMode(String view) async {
  await backendClient.call<void>('setViewMode', [view]);
}

Future<bool> getShowWindowsGames() async {
  return await backendClient.call<bool>('getShowWindowsGames');
}

Future<void> setShowWindowsGames(bool enabled) async {
  await backendClient.call<void>('setShowWindowsGames', [enabled]);
}

Future<bool> getShowHiddenGames() async {
  return await backendClient.call<bool>('getShowHiddenGames');
}

Future<void> setShowHiddenGames(bool enabled) async {
  await backendClient.call<void>('setShowHiddenGames', [enabled]);
}

Future<bool> getKeepInstallers() async {
  return await backendClient.call<bool>('getKeepInstallers');
}

Future<void> setKeepInstallers(bool enabled) async {
  await backendClient.call<void>('setKeepInstallers', [enabled]);
}

Future<String> getWinePrefix() async {
  return await backendClient.call<String>('getWinePrefix');
}

Future<void> setWinePrefix(String prefix) async {
  await backendClient.call<void>('setWinePrefix', [prefix]);
}

Future<String> getWineExecutable() async {
  return await backendClient.call<String>('getWineExecutable');
}

Future<void> setWineExecutable(String executable) async {
  await backendClient.call<void>('setWineExecutable', [executable]);
}

Future<bool> getWineDebug() async {
  return await backendClient.call<bool>('getWineDebug');
}

Future<void> setWineDebug(bool enabled) async {
  await backendClient.call<void>('setWineDebug', [enabled]);
}

Future<bool> getWineDisableNtsync() async {
  return await backendClient.call<bool>('getWineDisableNtsync');
}

Future<void> setWineDisableNtsync(bool enabled) async {
  await backendClient.call<void>('setWineDisableNtsync', [enabled]);
}

Future<bool> getWineAutoInstallDxvk() async {
  return await backendClient.call<bool>('getWineAutoInstallDxvk');
}

Future<void> setWineAutoInstallDxvk(bool enabled) async {
  await backendClient.call<void>('setWineAutoInstallDxvk', [enabled]);
}

// Additional Library API
Future<List<GameDto>> getCachedGames() async {
  final result = await backendClient.call<List<dynamic>>('getCachedGames');
  return result.map((e) => GameDto.fromJson(e as Map<String, dynamic>)).toList();
}

Future<int> scanForInstalledGames() async {
  return await backendClient.call<int>('scanForInstalledGames');
}

// Download API
Future<String> startDownload(int gameId) async {
  return await backendClient.call<String>('startDownload', [gameId]);
}

Future<GameDto> downloadAndInstall(int gameId) async {
  final result = await backendClient.call<Map<String, dynamic>>('downloadAndInstall', [gameId]);
  return GameDto.fromJson(result);
}

Future<void> pauseDownload(int gameId) async {
  await backendClient.call<void>('pauseDownload', [gameId]);
}

Future<void> cancelDownload(int gameId) async {
  await backendClient.call<void>('cancelDownload', [gameId]);
}

// Installation API
Future<GameDto> installGame(int gameId, String installerPath) async {
  final result = await backendClient.call<Map<String, dynamic>>('installGame', [gameId, installerPath]);
  return GameDto.fromJson(result);
}

Future<void> uninstallGame(int gameId) async {
  await backendClient.call<void>('uninstallGame', [gameId]);
}

Future<void> installDlc(int gameId, String dlcInstallerPath) async {
  await backendClient.call<void>('installDlc', [gameId, dlcInstallerPath]);
}

// Wine Tools API
Future<void> openWineConfig(int gameId) async {
  await backendClient.call<void>('openWineConfig', [gameId]);
}

Future<void> openWineRegedit(int gameId) async {
  await backendClient.call<void>('openWineRegedit', [gameId]);
}

Future<void> openWinetricks(int gameId) async {
  await backendClient.call<void>('openWinetricks', [gameId]);
}

// Additional stubs for functions not yet fully implemented
Future<String> getViewMode() async {
  return 'grid'; // Default to grid view
}

Future<bool> getShowWindowsGames() async {
  return true; // Default to showing Windows games
}

Future<List<GameDto>> getCachedGames() async {
  return await getLibrary(); // For now, just return library
}

Future<void> scanForInstalledGames() async {
  // TODO: Implement scanning
}

Future<void> setViewMode({required String view}) async {
  // TODO: Implement
}

Future<String> getInstallDir() async {
  final config = await getConfig();
  return config.installDir;
}

Future<String> getLanguage() async {
  final config = await getConfig();
  return config.lang;
}

Future<bool> getKeepInstallers() async {
  final config = await getConfig();
  return config.keepInstallers;
}

Future<String> getWinePrefix() async {
  final config = await getConfig();
  return config.winePrefix;
}

Future<String> getWineExecutable() async {
  final config = await getConfig();
  return config.wineExecutable;
}

Future<bool> getWineDebug() async {
  final config = await getConfig();
  return config.wineDebug;
}

Future<bool> getWineDisableNtsync() async {
  final config = await getConfig();
  return config.wineDisableNtsync;
}

Future<bool> getWineAutoInstallDxvk() async {
  final config = await getConfig();
  return config.wineAutoInstallDxvk;
}

Future<void> setLanguage({required String lang}) async {
  await setConfigValue('lang', lang);
}

Future<void> setShowWindowsGames({required bool enabled}) async {
  await setConfigValue('show_windows_games', enabled.toString());
}

Future<void> setKeepInstallers({required bool enabled}) async {
  await setConfigValue('keep_installers', enabled.toString());
}

Future<void> setWineDebug({required bool enabled}) async {
  await setConfigValue('wine_debug', enabled.toString());
}

Future<void> setWineDisableNtsync({required bool enabled}) async {
  await setConfigValue('wine_disable_ntsync', enabled.toString());
}

Future<void> setWineAutoInstallDxvk({required bool enabled}) async {
  await setConfigValue('wine_auto_install_dxvk', enabled.toString());
}
