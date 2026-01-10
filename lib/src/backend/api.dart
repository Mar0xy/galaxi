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

// Launch API
Future<LaunchResultDto> launchGameById(int gameId) async {
  final result = await backendClient.call<Map<String, dynamic>>('launchGameById', [gameId]);
  return LaunchResultDto.fromJson(result);
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
