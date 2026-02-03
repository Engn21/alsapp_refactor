import { Request, Response } from "express";
import axios from "axios";

function getCoords(req: Request) {
  const lat = Number(req.body?.lat ?? req.query.lat);
  const lon = Number(req.body?.lon ?? req.query.lon);
  return { lat, lon };
}

function kelvinToC(k: number | null | undefined) {
  if (typeof k !== "number" || Number.isNaN(k)) return null;
  return k - 273.15;
}

function normalizeCurrentWeather(data: any) {
  const entry = Array.isArray(data?.weather) ? data.weather[0] : null;
  const main = entry?.main?.toString() ?? "";
  const description = entry?.description?.toString() ?? undefined;

  const temp =
    typeof data?.main?.temp === "number" ? data.main.temp : undefined;
  const feelsLike =
    typeof data?.main?.feels_like === "number"
      ? data.main.feels_like
      : undefined;
  const humidity =
    typeof data?.main?.humidity === "number" ? data.main.humidity : undefined;
  const tempMin =
    typeof data?.main?.temp_min === "number" ? data.main.temp_min : undefined;
  const tempMax =
    typeof data?.main?.temp_max === "number" ? data.main.temp_max : undefined;
  const windSpeed =
    typeof data?.wind?.speed === "number"
      ? Number(data.wind.speed.toFixed(2))
      : undefined;
  const windGust =
    typeof data?.wind?.gust === "number"
      ? Number(data.wind.gust.toFixed(2))
      : undefined;

  const tempC = kelvinToC(temp ?? null);
  const hasRain = (Array.isArray(data?.weather) ? data.weather : []).some(
    (w: any) =>
      typeof w?.main === "string" && w.main.toLowerCase().includes("rain"),
  );

  return {
    weather: [
      {
        main,
        description,
      },
    ],
    main: {
      temp,
      feels_like: feelsLike,
      humidity,
      temp_min: tempMin,
      temp_max: tempMax,
    },
    wind: {
      speed: windSpeed,
      gust: windGust,
    },
    city: { name: data?.name },
    daily: {
      tempMinC: kelvinToC(tempMin ?? null),
      tempMaxC: kelvinToC(tempMax ?? null),
      humidityAvg: humidity ?? null,
      windAvg: windSpeed ?? null,
      windMax: windGust ?? windSpeed ?? null,
      hasRain,
      period: "today",
    },
    summary:
      tempC != null && main
        ? `${main} / ${tempC.toFixed(1)}°C`
        : main || undefined,
  };
}

export async function weather(req: Request, res: Response) {
  try {
    const { lat, lon } = getCoords(req);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      return res.status(400).json({ error: "Missing or invalid lat/lon" });
    }
    const apiKey = process.env.OPENWEATHER_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: "OPENWEATHER_API_KEY missing" });
    }

    const r = await axios.get(
      "https://api.openweathermap.org/data/2.5/weather",
      {
        params: { lat, lon, appid: apiKey },
        timeout: 8000,
      },
    );

    return res.json(r.data);
  } catch (e: any) {
    const status = e?.response?.status ?? 500;
    return res.status(status).json({ error: e?.message ?? "weather error" });
  }
}

export async function weatherSummary(req: Request, res: Response) {
  try {
    const { lat, lon } = getCoords(req);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      return res.status(400).json({ error: "Missing or invalid lat/lon" });
    }
    const apiKey = process.env.OPENWEATHER_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: "OPENWEATHER_API_KEY missing" });
    }

    const r = await axios.get(
      "https://api.openweathermap.org/data/2.5/weather",
      {
        params: { lat, lon, appid: apiKey },
        timeout: 8000,
      },
    );

    const data = r.data;
    const main = data?.weather?.[0]?.main ?? "";
    const c = data?.main?.temp != null ? data.main.temp - 273.15 : null;
    return res.json({
      summary: c != null ? `${main} / ${c.toFixed(1)}°C` : main,
    });
  } catch (e: any) {
    const status = e?.response?.status ?? 500;
    return res
      .status(status)
      .json({ error: e?.message ?? "weather summary error" });
  }
}

export async function weatherDaily(req: Request, res: Response) {
  try {
    const { lat, lon } = getCoords(req);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      return res.status(400).json({ error: "Missing or invalid lat/lon" });
    }
    const apiKey = process.env.OPENWEATHER_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: "OPENWEATHER_API_KEY missing" });
    }

    // Ücretsiz API için 5-day/3-hour forecast kullanıyoruz
    const response = await axios.get(
      "https://api.openweathermap.org/data/2.5/forecast",
      {
        params: {
          lat,
          lon,
          appid: apiKey,
        },
        timeout: 8000,
      },
    );

    const payload = response.data;
    const forecastList: any[] = Array.isArray(payload?.list) ? payload.list : [];
    if (!forecastList.length) {
      return res
        .status(502)
        .json({ error: "Weather forecast data unavailable" });
    }

    // Bugünün tarihini al (UTC)
    const now = new Date();
    const todayDateStr = now.toISOString().split("T")[0]; // YYYY-MM-DD

    // Bugüne ait tüm tahminleri filtrele
    const todayForecasts = forecastList.filter((item) => {
      const itemDate = new Date(item.dt * 1000).toISOString().split("T")[0];
      return itemDate === todayDateStr;
    });

    // Eğer bugün için tahmin yoksa, ilk tahminleri kullan
    const relevantForecasts = todayForecasts.length > 0
      ? todayForecasts
      : forecastList.slice(0, 8); // İlk 24 saat

    // Bugün için min/max sıcaklık, nem ortalaması, rüzgar max hesapla
    let tempMinK: number | undefined;
    let tempMaxK: number | undefined;
    let humiditySum = 0;
    let humidityCount = 0;
    let maxWindSpeed = 0;
    let maxWindGust = 0;
    let hasRain = false;

    const toNumber = (value: any) =>
      typeof value === "number" && Number.isFinite(value) ? value : undefined;

    relevantForecasts.forEach((item) => {
      const temp = toNumber(item?.main?.temp);
      const humidity = toNumber(item?.main?.humidity);
      const windSpeed = toNumber(item?.wind?.speed);
      const windGust = toNumber(item?.wind?.gust);

      if (temp != null) {
        if (tempMinK == null || temp < tempMinK) tempMinK = temp;
        if (tempMaxK == null || temp > tempMaxK) tempMaxK = temp;
      }

      if (humidity != null) {
        humiditySum += humidity;
        humidityCount++;
      }

      if (windSpeed != null && windSpeed > maxWindSpeed) {
        maxWindSpeed = windSpeed;
      }

      if (windGust != null && windGust > maxWindGust) {
        maxWindGust = windGust;
      }

      // Yağmur kontrolü
      if (Array.isArray(item?.weather)) {
        item.weather.forEach((w: any) => {
          const main = (w?.main ?? "").toString().toLowerCase();
          const desc = (w?.description ?? "").toString().toLowerCase();
          if (
            main.includes("rain") ||
            main.includes("storm") ||
            desc.includes("rain") ||
            desc.includes("storm")
          ) {
            hasRain = true;
          }
        });
      }
    });

    // İlk tahminin hava durumu bilgisini kullan
    const firstForecast = relevantForecasts[0] ?? {};
    const primaryWeather =
      Array.isArray(firstForecast?.weather) && firstForecast.weather.length
        ? firstForecast.weather[0]
        : null;

    const main =
      typeof primaryWeather?.main === "string" && primaryWeather.main
        ? primaryWeather.main
        : "Weather";
    const description =
      typeof primaryWeather?.description === "string" &&
      primaryWeather.description
        ? primaryWeather.description
        : undefined;

    const avgHumidity =
      humidityCount > 0 ? Math.round(humiditySum / humidityCount) : undefined;

    const tempMinC = kelvinToC(tempMinK);
    const tempMaxC = kelvinToC(tempMaxK);
    const tempAvgK = tempMinK != null && tempMaxK != null
      ? (tempMinK + tempMaxK) / 2
      : toNumber(firstForecast?.main?.temp);
    const tempAvgC = kelvinToC(tempAvgK);

    const summary =
      main && tempMinC != null && tempMaxC != null
        ? `${main} / ${tempMinC.toFixed(0)}-${tempMaxC.toFixed(0)}°C`
        : main && tempAvgC != null
          ? `${main} / ${tempAvgC.toFixed(1)}°C`
          : main || undefined;

    return res.json({
      weather: [
        {
          main,
          description,
        },
      ],
      main: {
        temp: tempAvgK,
        feels_like: toNumber(firstForecast?.main?.feels_like),
        humidity: avgHumidity,
        temp_min: tempMinK,
        temp_max: tempMaxK,
      },
      wind: {
        speed: maxWindSpeed > 0 ? Number(maxWindSpeed.toFixed(2)) : undefined,
        gust: maxWindGust > 0 ? Number(maxWindGust.toFixed(2)) : undefined,
      },
      city: payload?.city?.name ?? null,
      daily: {
        tempMinC: tempMinC != null ? Number(tempMinC.toFixed(1)) : null,
        tempMaxC: tempMaxC != null ? Number(tempMaxC.toFixed(1)) : null,
        humidityAvg: avgHumidity ?? null,
        windAvg: maxWindSpeed > 0 ? Number(maxWindSpeed.toFixed(2)) : null,
        windMax: maxWindGust > maxWindSpeed ? Number(maxWindGust.toFixed(2)) : maxWindSpeed > 0 ? Number(maxWindSpeed.toFixed(2)) : null,
        hasRain,
        period: "today",
      },
      summary,
    });
  } catch (e: any) {
    const status = e?.response?.status ?? 500;
    return res
      .status(status)
      .json({ error: e?.message ?? "weather daily error" });
  }
}
