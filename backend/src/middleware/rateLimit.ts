import rateLimit from "express-rate-limit";

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
