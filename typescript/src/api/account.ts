import { GogApi, UserProfile } from './gog_api';
import { AccountDto, UserDataDto, UserProfileDto } from './dto';
import { accountsDb } from './database';

export async function fetchUserAvatar(api: GogApi, userId: string): Promise<string | undefined> {
  try {
    const profile = await api.getUserProfile(userId);
    return profile.avatars?.medium;
  } catch (error) {
    return undefined;
  }
}

export class Account {
  user_id: string;
  username: string;
  refresh_token: string;
  avatar_url?: string;

  constructor(userId: string, username: string, refreshToken: string, avatarUrl?: string) {
    this.user_id = userId;
    this.username = username;
    this.refresh_token = refreshToken;
    this.avatar_url = avatarUrl;
  }

  toDto(): AccountDto {
    return {
      user_id: this.user_id,
      username: this.username,
      refresh_token: this.refresh_token,
      avatar_url: this.avatar_url,
    };
  }

  static fromDto(dto: AccountDto): Account {
    return new Account(dto.user_id, dto.username, dto.refresh_token, dto.avatar_url);
  }
}
