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
const livestock_1 = __importDefault(require("./routes/livestock"));
const weather_1 = __importDefault(require("./routes/weather"));
const supports_1 = __importDefault(require("./routes/supports"));
const dash_1 = __importDefault(require("./routes/dash"));
const notifications_1 = __importDefault(require("./routes/notifications"));
const error_1 = require("./middleware/error");
const IS_PROD = process.env.NODE_ENV === "production";
const ALLOWED_ORIGINS = (process.env.CORS_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
function createServer() {
    const app = (0, express_1.default)();
    // CORS (sadece web tarayıcısı için gerekir; mobil native'de yok)
    app.use((0, cors_1.default)({
        origin: (origin, cb) => {
            if (!origin)
                return cb(null, true); // mobil/native istekler ya da curl
            if (!IS_PROD) {
                const ok = /^http:\/\/localhost:\d+$/.test(origin) ||
                    /^http:\/\/127\.0\.0\.1:\d+$/.test(origin);
                return cb(null, ok);
            }
            const ok = ALLOWED_ORIGINS.includes(origin);
            return cb(ok ? null : new Error("CORS blocked"), ok);
        },
        methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allowedHeaders: ["Content-Type", "Authorization", "X-Requested-With"],
        credentials: false, // cookie kullanmıyorsan true yapma
        optionsSuccessStatus: 204,
        preflightContinue: false
    }));
    app.use(express_1.default.json());
    // Basit log (OPTIONS dahil)
    app.use((req, _res, next) => {
        console.log(`${req.method} ${req.path}`);
        next();
    });
    // Güvenlik başlıkları (XHR akışını bozmadan)
    app.use((0, helmet_1.default)({
        crossOriginEmbedderPolicy: false,
        crossOriginResourcePolicy: { policy: "cross-origin" }
    }));
    // ---- ROUTES ---- (güncel akışı aynen korur)
    app.use("/api/auth", auth_1.default);
    app.use("/api/crops", crops_1.default);
    app.use("/api/livestock", livestock_1.default);
    app.use("/api/weather", weather_1.default);
    app.use("/api/supports", supports_1.default);
    app.use("/api/dash", dash_1.default);
    app.use("/api/notifications", notifications_1.default);
    // Sağlık kontrolü
    app.get("/health", (_req, res) => res.json({ ok: true }));
    // 404
    app.use((req, _res, next) => {
        const err = new Error(`Not Found: ${req.method} ${req.path}`);
        err.status = 404;
        next(err);
    });
    // Hata yakalayıcı (EN SON)
    app.use(error_1.errorHandler);
    return app;
}
