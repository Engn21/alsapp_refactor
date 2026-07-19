import { Router } from "express";
import { weather, weatherSummary, weatherDaily } from "../controllers/weather.controller";
import { weatherLimiter } from "../middleware/rateLimit";
import { requireAuth } from "../middleware/auth";

const router = Router();

router.use(requireAuth);
router.use(weatherLimiter);

// /api/weather (server.ts mounts this route under /api/weather)
router.post("/", weather);
router.get("/", weather);

// /api/weather/summary
router.get("/summary", weatherSummary);

// /api/weather/daily
router.get("/daily", weatherDaily);

export default router;
