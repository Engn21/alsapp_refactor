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

export function createServer() {
  // Computed inside createServer() (not at module load time): TypeScript
  // hoists all `import`-derived requires above other top-level code, so
  // index.ts's dotenv.config() call runs after this module is required.
  // Reading process.env here (at call time, once index.ts has already
  // called dotenv.config()) ensures CORS_ORIGINS/NODE_ENV are populated.
  const IS_PROD = process.env.NODE_ENV === "production";
  const ALLOWED_ORIGINS = (process.env.CORS_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  const app = express();

  // CORS (only needed for the web browser; native mobile doesn't need it)
  app.use(
    cors({
      origin: (origin, cb) => {
        if (!origin) return cb(null, true); // mobile/native requests or curl
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
      credentials: false, // set true only if you start using cookies
      optionsSuccessStatus: 204,
      preflightContinue: false
    })
  );

  app.use(express.json());

  // Simple request log (includes OPTIONS)
  app.use((req, _res, next) => {
    console.log(`${req.method} ${req.path}`);
    next();
  });

  // Security headers (without breaking the XHR flow)
  app.use(
    helmet({
      crossOriginEmbedderPolicy: false,
      crossOriginResourcePolicy: { policy: "cross-origin" }
    })
  );

  // ---- ROUTES ---- (keeps the existing flow as-is)
  app.use("/api/auth", authRoutes);
  app.use("/api/crops", cropRoutes);
  app.use("/api/livestock", livestockRoutes);
  app.use("/api/weather", weatherRoutes);
  app.use("/api/supports", supportsRoutes);
  app.use("/api/dash", dashRoutes);
  app.use("/api/notifications", notificationRoutes);

  // Health check
  app.get("/health", (_req, res) => res.json({ ok: true }));

  // 404
  app.use((req, _res, next) => {
    const err: any = new Error(`Not Found: ${req.method} ${req.path}`);
    err.status = 404;
    next(err);
  });

  // Error handler (must be LAST)
  app.use(errorHandler);

  return app;
}
