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

class GameInfoDto {
  final int id;
  final String title;
  final String? description;
  final String? changelog;
  final List<String> screenshots;

  GameInfoDto({
    required this.id,
    required this.title,
    this.description,
    this.changelog,
    required this.screenshots,
  });

  factory GameInfoDto.fromJson(Map<String, dynamic> json) {
    return GameInfoDto(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      changelog: json['changelog'] as String?,
      screenshots: (json['screenshots'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class GamesDbInfoDto {
  final String cover;
  final String verticalCover;
  final String background;
  final String summary;
  final String genre;

  GamesDbInfoDto({
    required this.cover,
    required this.verticalCover,
    required this.background,
    required this.summary,
    required this.genre,
  });

  factory GamesDbInfoDto.fromJson(Map<String, dynamic> json) {
    return GamesDbInfoDto(
      cover: json['cover'] as String,
      verticalCover: json['vertical_cover'] as String,
      background: json['background'] as String,
      summary: json['summary'] as String,
      genre: json['genre'] as String,
    );
  }
}

class DownloadProgressDto {
  final int gameId;
  final String gameName;
  final int downloadedBytes;
  final int totalBytes;
  final int speedBytesPerSec;
  final String status;

  DownloadProgressDto({
    required this.gameId,
    required this.gameName,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytesPerSec,
    required this.status,
  });

  factory DownloadProgressDto.fromJson(Map<String, dynamic> json) {
    return DownloadProgressDto(
      gameId: json['game_id'] as int,
      gameName: json['game_name'] as String,
      downloadedBytes: json['downloaded_bytes'] as int,
      totalBytes: json['total_bytes'] as int,
      speedBytesPerSec: json['speed_bytes_per_sec'] as int,
      status: json['status'] as String,
    );
  }
}
