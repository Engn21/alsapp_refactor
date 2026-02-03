import { Router } from "express";
import { weather, weatherSummary, weatherDaily } from "../controllers/weather.controller";

const router = Router();

// /api/weather  (server.ts bu route'u /api/weather altında mount edecek)
router.post("/", weather);
router.get("/", weather);

// /api/weather/summary
router.get("/summary", weatherSummary);

// /api/weather/daily
router.get("/daily", weatherDaily);

export default router;
