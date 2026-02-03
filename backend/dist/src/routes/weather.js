"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const weather_controller_1 = require("../controllers/weather.controller");
const router = (0, express_1.Router)();
// /api/weather  (server.ts bu route'u /api/weather altında mount edecek)
router.post("/", weather_controller_1.weather);
router.get("/", weather_controller_1.weather);
// /api/weather/summary
router.get("/summary", weather_controller_1.weatherSummary);
exports.default = router;
