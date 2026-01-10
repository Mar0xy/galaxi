import { GogApi } from './gog_api';
import { AccountDto } from './dto';
export declare function fetchUserAvatar(api: GogApi, userId: string): Promise<string | undefined>;
export declare class Account {
    user_id: string;
    username: string;
    refresh_token: string;
    avatar_url?: string;
    constructor(userId: string, username: string, refreshToken: string, avatarUrl?: string);
    toDto(): AccountDto;
    static fromDto(dto: AccountDto): Account;
}
//# sourceMappingURL=account.d.ts.map