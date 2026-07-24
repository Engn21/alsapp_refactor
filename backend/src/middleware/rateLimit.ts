import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import { AuthedRequest } from "./auth";

// Limits brute-force login attempts and register spam per IP.
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: "Too many attempts, please try again later." },
});

// Weather routes proxy to a metered third-party API (OpenWeather); this
// keeps a single client from exhausting the shared API quota.
export const weatherLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: "Too many weather requests, please slow down." },
});

// Each assistant message can trigger several Claude API round-trips (the
// tool-use loop), so this is tighter than weatherLimiter. Keyed by user id
// (not just IP) since this only ever runs behind requireAuth.
export const assistantLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 8,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) =>
    (req as AuthedRequest).user?.id ?? ipKeyGenerator(req.ip ?? "unknown"),
  message: { message: "Too many assistant requests, please slow down." },
});
