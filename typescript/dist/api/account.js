"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Account = void 0;
exports.fetchUserAvatar = fetchUserAvatar;
async function fetchUserAvatar(api, userId) {
    try {
        const profile = await api.getUserProfile(userId);
        return profile.avatars?.medium;
    }
    catch (error) {
        return undefined;
    }
}
class Account {
    constructor(userId, username, refreshToken, avatarUrl) {
        this.user_id = userId;
        this.username = username;
        this.refresh_token = refreshToken;
        this.avatar_url = avatarUrl;
    }
    toDto() {
        return {
            user_id: this.user_id,
            username: this.username,
            refresh_token: this.refresh_token,
            avatar_url: this.avatar_url,
        };
    }
    static fromDto(dto) {
        return new Account(dto.user_id, dto.username, dto.refresh_token, dto.avatar_url);
    }
}
exports.Account = Account;
//# sourceMappingURL=account.js.map