"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.weather = weather;
exports.weatherSummary = weatherSummary;
const axios_1 = __importDefault(require("axios"));
function getCoords(req) {
    const lat = Number(req.body?.lat ?? req.query.lat);
    const lon = Number(req.body?.lon ?? req.query.lon);
    return { lat, lon };
}
async function weather(req, res) {
    try {
        const { lat, lon } = getCoords(req);
        if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
            return res.status(400).json({ error: "Missing or invalid lat/lon" });
        }
        const apiKey = process.env.OPENWEATHER_API_KEY;
        if (!apiKey)
            return res.status(500).json({ error: "OPENWEATHER_API_KEY missing" });
        const r = await axios_1.default.get("https://api.openweathermap.org/data/2.5/weather", {
            params: { lat, lon, appid: apiKey },
            timeout: 8000,
        });
        return res.json(r.data);
    }
    catch (e) {
        const status = e?.response?.status ?? 500;
        return res.status(status).json({ error: e?.message ?? "weather error" });
    }
}
async function weatherSummary(req, res) {
    try {
        const { lat, lon } = getCoords(req);
        if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
            return res.status(400).json({ error: "Missing or invalid lat/lon" });
        }
        const apiKey = process.env.OPENWEATHER_API_KEY;
        if (!apiKey)
            return res.status(500).json({ error: "OPENWEATHER_API_KEY missing" });
        const r = await axios_1.default.get("https://api.openweathermap.org/data/2.5/weather", {
            params: { lat, lon, appid: apiKey },
            timeout: 8000,
        });
        const data = r.data;
        const main = data?.weather?.[0]?.main ?? "";
        const c = data?.main?.temp != null ? data.main.temp - 273.15 : null;
        return res.json({ summary: c != null ? `${main} / ${c.toFixed(1)}°C` : main });
    }
    catch (e) {
        const status = e?.response?.status ?? 500;
        return res.status(status).json({ error: e?.message ?? "weather summary error" });
    }
}
