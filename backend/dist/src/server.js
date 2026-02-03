"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createServer = createServer;
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const auth_1 = __importDefault(require("./routes/auth"));
const crops_1 = __importDefault(require("./routes/crops"));
const error_1 = require("./middleware/error");
function createServer() {
    const app = (0, express_1.default)();
    // 1) CORS — en başta ve preflight'ı elde kapat
    app.use((req, res, next) => {
        const origin = req.headers.origin ?? "*";
        res.header("Access-Control-Allow-Origin", origin);
        res.header("Vary", "Origin");
        res.header("Access-Control-Allow-Credentials", "true");
        res.header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
        res.header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With");
        if (req.method === "OPTIONS")
            return res.sendStatus(204); // preflight'e anında 204
        next();
    });
    // (İsteğe bağlı) cors paketi de dursun; origin'i otomatik yansıtır
    app.use((0, cors_1.default)({ origin: true, credentials: true }));
    // 2) Body parser
    app.use(express_1.default.json());
    // 3) Basit log: isteğin gerçekten sunucuya ulaşıp ulaşmadığını görmek için
    app.use((req, _res, next) => {
        console.log(req.method, req.path);
        next();
    });
    // 4) Helmet (CORS ile çakışmasın diye gevşek)
    app.use((0, helmet_1.default)({
        crossOriginEmbedderPolicy: false,
        crossOriginResourcePolicy: { policy: "cross-origin" },
    }));
    // 5) Rotalar
    app.use("/api/auth", auth_1.default);
    app.use("/api/crops", crops_1.default);
    app.get("/health", (_req, res) => res.json({ ok: true }));
    // 6) Hata yakalayıcı
    app.use(error_1.errorHandler);
    return app;
}
