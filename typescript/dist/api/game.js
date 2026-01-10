"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Game = exports.Dlc = void 0;
class Dlc {
    constructor(id, name, title, imageUrl) {
        this.id = id;
        this.name = name;
        this.title = title;
        this.image_url = imageUrl;
    }
    toDto() {
        return {
            id: this.id,
            name: this.name,
            title: this.title,
            image_url: this.image_url,
        };
    }
}
exports.Dlc = Dlc;
class Game {
    constructor(name, url, id, installDir, imageUrl, platform, category) {
        this.name = name;
        this.url = url;
        this.md5sum = {};
        this.id = id;
        this.install_dir = installDir;
        this.image_url = imageUrl;
        this.platform = platform;
        this.dlcs = [];
        this.category = category;
    }
    toDto() {
        return {
            id: this.id,
            name: this.name,
            url: this.url,
            install_dir: this.install_dir,
            image_url: this.image_url,
            platform: this.platform,
            category: this.category,
            dlcs: this.dlcs.map(d => d.toDto()),
        };
    }
    static fromDto(dto) {
        const game = new Game(dto.name, dto.url, dto.id, dto.install_dir, dto.image_url, dto.platform, dto.category);
        game.dlcs = dto.dlcs.map(d => new Dlc(d.id, d.name, d.title, d.image_url));
        return game;
    }
}
exports.Game = Game;
//# sourceMappingURL=game.js.map