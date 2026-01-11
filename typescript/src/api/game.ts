import { GameDto, DlcDto } from './dto';

export class Dlc {
  id: number;
  name: string;
  title: string;
  image_url: string;

  constructor(id: number, name: string, title: string, imageUrl: string) {
    this.id = id;
    this.name = name;
    this.title = title;
    this.image_url = imageUrl;
  }

  toDto(): DlcDto {
    return {
      id: this.id,
      name: this.name,
      title: this.title,
      image_url: this.image_url,
    };
  }
}

export class Game {
  name: string;
  url: string;
  md5sum: Record<string, string>;
  id: number;
  install_dir: string;
  image_url: string;
  platform: string;
  dlcs: Dlc[];
  category: string;

  constructor(
    name: string,
    url: string,
    id: number,
    installDir: string,
    imageUrl: string,
    platform: string,
    category: string
  ) {
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

  toDto(): GameDto {
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

  static fromDto(dto: GameDto): Game {
    const game = new Game(
      dto.name,
      dto.url,
      dto.id,
      dto.install_dir,
      dto.image_url,
      dto.platform,
      dto.category
    );
    game.dlcs = dto.dlcs.map(d => new Dlc(d.id, d.name, d.title, d.image_url));
    return game;
  }

  /**
   * Get a sanitized folder name for this game, removing special characters
   * that are not allowed in folder names (like : * ? " < > |)
   */
  getInstallDirectoryName(): string {
    // Keep only alphanumeric characters and whitespace, then trim
    return this.name
      .split('')
      .filter(c => /[a-zA-Z0-9\s]/.test(c))
      .join('')
      .trim();
  }
}
