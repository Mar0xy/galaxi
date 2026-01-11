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

Future<AccountDto> addCurrentAccount({required String refreshToken}) async {
  final result = await backendClient.call<Map<String, dynamic>>('addCurrentAccount', [refreshToken]);
  return AccountDto.fromJson(result);
}

Future<bool> switchAccount({required String userId}) async {
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

Future<void> setDarkTheme({required bool enabled}) async {
  await backendClient.call<void>('setDarkTheme', [enabled]);
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

Future<void> setLanguage({required String lang}) async {
  await backendClient.call<void>('setLanguage', [lang]);
}

Future<String> getViewMode() async {
  return await backendClient.call<String>('getViewMode');
}

Future<void> setViewMode({required String view}) async {
  await backendClient.call<void>('setViewMode', [view]);
}

Future<bool> getShowWindowsGames() async {
  return await backendClient.call<bool>('getShowWindowsGames');
}

Future<void> setShowWindowsGames({required bool enabled}) async {
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

Future<void> setKeepInstallers({required bool enabled}) async {
  await backendClient.call<void>('setKeepInstallers', [enabled]);
}

Future<String> getWinePrefix() async {
  return await backendClient.call<String>('getWinePrefix');
}

Future<void> setWinePrefix({required String prefix}) async {
  await backendClient.call<void>('setWinePrefix', [prefix]);
}

Future<String> getWineExecutable() async {
  return await backendClient.call<String>('getWineExecutable');
}

Future<void> setWineExecutable({required String executable}) async {
  await backendClient.call<void>('setWineExecutable', [executable]);
}

Future<bool> getWineDebug() async {
  return await backendClient.call<bool>('getWineDebug');
}

Future<void> setWineDebug({required bool enabled}) async {
  await backendClient.call<void>('setWineDebug', [enabled]);
}

Future<bool> getWineDisableNtsync() async {
  return await backendClient.call<bool>('getWineDisableNtsync');
}

Future<void> setWineDisableNtsync({required bool enabled}) async {
  await backendClient.call<void>('setWineDisableNtsync', [enabled]);
}

Future<bool> getWineAutoInstallDxvk() async {
  return await backendClient.call<bool>('getWineAutoInstallDxvk');
}

Future<void> setWineAutoInstallDxvk({required bool enabled}) async {
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
Future<String> startDownload({required int gameId}) async {
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

Future<DownloadProgressDto?> getDownloadProgress({required int gameId}) async {
  final result = await backendClient.call<Map<String, dynamic>?>('getDownloadProgress', [gameId]);
  return result != null ? DownloadProgressDto.fromJson(result) : null;
}

// Installation API
Future<GameDto> installGame({required int gameId, required String installerPath}) async {
  final result = await backendClient.call<Map<String, dynamic>>('installGame', [gameId, installerPath]);
  return GameDto.fromJson(result);
}

Future<void> uninstallGame({required int gameId}) async {
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

// Additional API functions
Future<GameInfoDto> getGameInfo({required int gameId}) async {
  final result = await backendClient.call<Map<String, dynamic>>('getGameInfo', [gameId]);
  return GameInfoDto.fromJson(result);
}

Future<GamesDbInfoDto> getGamesdbInfo({required int gameId}) async {
  final result = await backendClient.call<Map<String, dynamic>>('getGamesDbInfo', [gameId]);
  return GamesDbInfoDto.fromJson(result);
}

Future<LaunchResultDto> launchGameById(int gameId) async {
  final result = await backendClient.call<Map<String, dynamic>>('launchGameById', [gameId]);
  return LaunchResultDto.fromJson(result);
}

Future<LaunchResultDto> launchGameAsync({required int gameId}) async {
  return await launchGameById(gameId);
}

// Game Session Tracking API
Future<bool> isGameRunning(int gameId) async {
  return await backendClient.call<bool>('isGameRunning', [gameId]);
}

Future<int> getGamePlaytime(int gameId) async {
  return await backendClient.call<int>('getGamePlaytime', [gameId]);
}

Future<int> getTotalGamePlaytime(int gameId) async {
  return await backendClient.call<int>('getTotalGamePlaytime', [gameId]);
}

Future<Map<String, dynamic>?> getRunningGame() async {
  return await backendClient.call<Map<String, dynamic>?>('getRunningGame');
}

List<Map<String, String>> getSupportedLanguages() {
  return [
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'it', 'name': 'Italian'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'pl', 'name': 'Polish'},
    {'code': 'zh', 'name': 'Chinese'},
  ];
}

Future<void> openWineConfigGlobal() async {
  // Open winecfg without a specific game
  // For now, just throw an error to indicate it's not implemented yet
  throw UnimplementedError('Global Wine config not yet implemented');
}

Future<void> openWinetricksGlobal() async {
  // Open winetricks without a specific game
  throw UnimplementedError('Global Winetricks not yet implemented');
}

