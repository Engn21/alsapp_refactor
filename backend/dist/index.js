"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const server_1 = require("./server");
const PORT = Number(process.env.PORT || 8080);
// Tüm arayüzlerde dinle: web/emülatör/gerçek cihaz erişsin
const HOST = process.env.HOST || "0.0.0.0";
const app = (0, server_1.createServer)();
app.listen(PORT, HOST, () => {
    console.log(`API listening on http://${HOST}:${PORT}`);
});
// Görünmeyen hataları da konsola düşür
process.on("unhandledRejection", (e) => console.error(e));
process.on("uncaughtException", (e) => console.error(e));
