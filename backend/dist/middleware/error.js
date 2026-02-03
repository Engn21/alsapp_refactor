"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorHandler = errorHandler;
// Named export (server.ts içinde: import { errorHandler } from "./middleware/error")
function errorHandler(err, _req, res, _next) {
    // Konsola tam hata düşsün
    console.error(err);
    const status = typeof err?.status === "number" ? err.status : 500;
    const message = err?.message || "Internal Server Error";
    res.status(status).json({ message });
}
