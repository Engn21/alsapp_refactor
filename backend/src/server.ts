import express from "express";
import cors from "cors";
import helmet from "helmet";

import authRoutes from "./routes/auth";
import cropRoutes from "./routes/crops";
import livestockRoutes from "./routes/livestock";
import weatherRoutes from "./routes/weather";
import supportsRoutes from "./routes/supports";
import dashRoutes from "./routes/dash";
import notificationRoutes from "./routes/notifications";
import { errorHandler } from "./middleware/error";

const IS_PROD = process.env.NODE_ENV === "production";
const ALLOWED_ORIGINS = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

export function createServer() {
  const app = express();

  // CORS (sadece web tarayıcısı için gerekir; mobil native'de yok)
  app.use(
    cors({
      origin: (origin, cb) => {
        if (!origin) return cb(null, true); // mobil/native istekler ya da curl
        if (!IS_PROD) {
          const ok =
            /^http:\/\/localhost:\d+$/.test(origin) ||
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
    })
  );

  app.use(express.json());

  // Basit log (OPTIONS dahil)
  app.use((req, _res, next) => {
    console.log(`${req.method} ${req.path}`);
    next();
  });

  // Güvenlik başlıkları (XHR akışını bozmadan)
  app.use(
    helmet({
      crossOriginEmbedderPolicy: false,
      crossOriginResourcePolicy: { policy: "cross-origin" }
    })
  );

  // ---- ROUTES ---- (güncel akışı aynen korur)
  app.use("/api/auth", authRoutes);
  app.use("/api/crops", cropRoutes);
  app.use("/api/livestock", livestockRoutes);
  app.use("/api/weather", weatherRoutes);
  app.use("/api/supports", supportsRoutes);
  app.use("/api/dash", dashRoutes);
  app.use("/api/notifications", notificationRoutes);

  // Sağlık kontrolü
  app.get("/health", (_req, res) => res.json({ ok: true }));

  // 404
  app.use((req, _res, next) => {
    const err: any = new Error(`Not Found: ${req.method} ${req.path}`);
    err.status = 404;
    next(err);
  });

  // Hata yakalayıcı (EN SON)
  app.use(errorHandler);

  return app;
}
