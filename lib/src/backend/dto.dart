// Data Transfer Objects for Flutter

class GameDto {
  final int id;
  final String name;
  final String url;
  final String installDir;
  final String imageUrl;
  final String platform;
  final String category;
  final List<DlcDto> dlcs;

  GameDto({
    required this.id,
    required this.name,
    required this.url,
    required this.installDir,
    required this.imageUrl,
    required this.platform,
    required this.category,
    required this.dlcs,
  });

  factory GameDto.fromJson(Map<String, dynamic> json) {
    return GameDto(
      id: json['id'] as int,
      name: json['name'] as String,
      url: json['url'] as String,
      installDir: json['install_dir'] as String,
      imageUrl: json['image_url'] as String,
      platform: json['platform'] as String,
      category: json['category'] as String,
      dlcs: (json['dlcs'] as List?)
              ?.map((e) => DlcDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DlcDto {
  final int id;
  final String name;
  final String title;
  final String imageUrl;

  DlcDto({
    required this.id,
    required this.name,
    required this.title,
    required this.imageUrl,
  });

  factory DlcDto.fromJson(Map<String, dynamic> json) {
    return DlcDto(
      id: json['id'] as int,
      name: json['name'] as String,
      title: json['title'] as String,
      imageUrl: json['image_url'] as String,
    );
  }
}

class AccountDto {
  final String userId;
  final String username;
  final String refreshToken;
  final String? avatarUrl;

  AccountDto({
    required this.userId,
    required this.username,
    required this.refreshToken,
    this.avatarUrl,
  });

  factory AccountDto.fromJson(Map<String, dynamic> json) {
    return AccountDto(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      refreshToken: json['refresh_token'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class UserDataDto {
  final String userId;
  final String username;
  final String? email;

  UserDataDto({
    required this.userId,
    required this.username,
    this.email,
  });

  factory UserDataDto.fromJson(Map<String, dynamic> json) {
    return UserDataDto(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
    );
  }
}

class ConfigDto {
  final String locale;
  final String lang;
  final String view;
  final String installDir;
  final bool keepInstallers;
  final bool stayLoggedIn;
  final bool useDarkTheme;
  final bool showHiddenGames;
  final bool showWindowsGames;
  final String winePrefix;
  final String wineExecutable;
  final bool wineDebug;
  final bool wineDisableNtsync;
  final bool wineAutoInstallDxvk;

  ConfigDto({
    required this.locale,
    required this.lang,
    required this.view,
    required this.installDir,
    required this.keepInstallers,
    required this.stayLoggedIn,
    required this.useDarkTheme,
    required this.showHiddenGames,
    required this.showWindowsGames,
    required this.winePrefix,
    required this.wineExecutable,
    required this.wineDebug,
    required this.wineDisableNtsync,
    required this.wineAutoInstallDxvk,
  });

  factory ConfigDto.fromJson(Map<String, dynamic> json) {
    return ConfigDto(
      locale: json['locale'] as String,
      lang: json['lang'] as String,
      view: json['view'] as String,
      installDir: json['install_dir'] as String,
      keepInstallers: json['keep_installers'] as bool,
      stayLoggedIn: json['stay_logged_in'] as bool,
      useDarkTheme: json['use_dark_theme'] as bool,
      showHiddenGames: json['show_hidden_games'] as bool,
      showWindowsGames: json['show_windows_games'] as bool,
      winePrefix: json['wine_prefix'] as String,
      wineExecutable: json['wine_executable'] as String,
      wineDebug: json['wine_debug'] as bool,
      wineDisableNtsync: json['wine_disable_ntsync'] as bool,
      wineAutoInstallDxvk: json['wine_auto_install_dxvk'] as bool,
    );
  }
}

class LaunchResultDto {
  final bool success;
  final String? errorMessage;
  final int? pid;

  LaunchResultDto({
    required this.success,
    this.errorMessage,
    this.pid,
  });

  factory LaunchResultDto.fromJson(Map<String, dynamic> json) {
    return LaunchResultDto(
      success: json['success'] as bool,
      errorMessage: json['error_message'] as String?,
      pid: json['pid'] as int?,
    );
  }
}
