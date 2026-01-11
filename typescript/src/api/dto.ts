// Data Transfer Objects for Flutter API

export interface GameDto {
  id: number;
  name: string;
  url: string;
  install_dir: string;
  image_url: string;
  platform: string;
  category: string;
  dlcs: DlcDto[];
}

export interface DlcDto {
  id: number;
  name: string;
  title: string;
  image_url: string;
}

export interface AccountDto {
  user_id: string;
  username: string;
  refresh_token: string;
  avatar_url?: string;
}

export interface UserDataDto {
  user_id: string;
  username: string;
  email?: string;
}

export interface UserProfileDto {
  user_id: string;
  username: string;
  avatar_url?: string;
}

export interface DownloadProgressDto {
  game_id: number;
  game_name: string;
  downloaded_bytes: number;
  total_bytes: number;
  speed_bytes_per_sec: number;
  status: string;
}

export interface GameInfoDto {
  id: number;
  title: string;
  description?: string;
  changelog?: string;
  screenshots: string[];
}

export interface GamesDbInfoDto {
  cover: string;
  vertical_cover: string;
  background: string;
  summary: string;
  genre: string;
}

export interface LaunchResultDto {
  success: boolean;
  error_message?: string;
  pid?: number;
}

export interface ConfigDto {
  locale: string;
  lang: string;
  view: string;
  install_dir: string;
  keep_installers: boolean;
  stay_logged_in: boolean;
  use_dark_theme: boolean;
  show_hidden_games: boolean;
  show_windows_games: boolean;
  wine_prefix: string;
  wine_executable: string;
  wine_debug: boolean;
  wine_disable_ntsync: boolean;
  wine_auto_install_dxvk: boolean;
}
