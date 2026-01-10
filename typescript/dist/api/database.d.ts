import { AccountDto, GameDto } from './dto';
export declare function getDbPath(): string;
export declare function initDatabase(): void;
export declare function getConfigValue(key: string): string;
export declare function setConfigValue(key: string, value: string): void;
export declare function accountsDb(): {
    addAccount(account: AccountDto): void;
    getAccount(userId: string): AccountDto | null;
    getAllAccounts(): AccountDto[];
    getActiveAccount(): AccountDto | null;
    setActiveAccount(userId: string): void;
    removeAccount(userId: string): void;
    updateAvatar(userId: string, avatarUrl: string): void;
};
export declare function gamesDb(): {
    saveGame(game: GameDto): void;
    getGame(gameId: number): GameDto | null;
    getAllGames(): GameDto[];
    clearGames(): void;
};
export declare function closeDatabase(): void;
//# sourceMappingURL=database.d.ts.map