"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
// Main entry point for the Galaxi TypeScript backend
__exportStar(require("./api/simple"), exports);
__exportStar(require("./api/dto"), exports);
__exportStar(require("./api/error"), exports);
__exportStar(require("./api/config"), exports);
__exportStar(require("./api/gog_api"), exports);
// export * from './api/game'; // Exported via gog_api
__exportStar(require("./api/account"), exports);
__exportStar(require("./api/download"), exports);
__exportStar(require("./api/installer"), exports);
__exportStar(require("./api/launcher"), exports);
// Don't export database to avoid conflicts
// export * from './api/database';
//# sourceMappingURL=index.js.map