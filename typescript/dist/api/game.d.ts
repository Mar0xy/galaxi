import { GameDto, DlcDto } from './dto';
export declare class Dlc {
    id: number;
    name: string;
    title: string;
    image_url: string;
    constructor(id: number, name: string, title: string, imageUrl: string);
    toDto(): DlcDto;
}
export declare class Game {
    name: string;
    url: string;
    md5sum: Record<string, string>;
    id: number;
    install_dir: string;
    image_url: string;
    platform: string;
    dlcs: Dlc[];
    category: string;
    constructor(name: string, url: string, id: number, installDir: string, imageUrl: string, platform: string, category: string);
    toDto(): GameDto;
    static fromDto(dto: GameDto): Game;
}
//# sourceMappingURL=game.d.ts.map