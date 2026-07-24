import { listCropsForUser } from "../../controllers/crops.controller";
import { listLivestockForUser } from "../../controllers/livestock.controller";
import { listMatchedSupportPrograms } from "../../controllers/supports.controller";
import { fetchCurrentWeather, fetchDailyForecast } from "../../controllers/weather.controller";
import { listNotifications } from "../notifications";

export interface ToolCtx {
  userId: string;
  lang: string;
  lat?: number;
  lon?: number;
}

// Cost guardrail: cap the top-level record count sent to Claude, and as a
// final belt-and-suspenders guard, cap the serialized string length too -
// protects against a farm with an unusually large number of records
// blowing up token cost in a single tool result.
const MAX_RECORDS: Record<string, number> = {
  get_crops: 30,
  get_livestock: 30,
  get_support_programs: 15,
  get_notifications: 20,
};
const MAX_JSON_CHARS = 6000;

function toToolResult(toolName: string, data: unknown[]): string {
  const max = MAX_RECORDS[toolName];
  const omitted = max && data.length > max ? data.length - max : 0;
  const capped = omitted ? data.slice(0, max) : data;
  let json = JSON.stringify(capped);
  if (json.length > MAX_JSON_CHARS) {
    json = `${json.slice(0, MAX_JSON_CHARS)}... [truncated]`;
  }
  return omitted ? `${json}\n\n(...${omitted} more records omitted)` : json;
}

export const toolExecutors: Record<
  string,
  (input: any, ctx: ToolCtx) => Promise<{ result: string; isError: boolean }>
> = {
  async get_crops(input, ctx) {
    let crops = await listCropsForUser(ctx.userId);
    if (input?.cropType) {
      const needle = input.cropType.toString().toLowerCase();
      crops = crops.filter((c: any) => c.cropType?.toLowerCase().includes(needle));
    }
    return { result: toToolResult("get_crops", crops), isError: false };
  },

  async get_livestock(input, ctx) {
    let livestock = await listLivestockForUser(ctx.userId);
    if (input?.species) {
      const needle = input.species.toString().toLowerCase();
      livestock = livestock.filter((l: any) => l.species?.toLowerCase().includes(needle));
    }
    return { result: toToolResult("get_livestock", livestock), isError: false };
  },

  async get_weather(input, ctx) {
    const lat = typeof input?.lat === "number" ? input.lat : ctx.lat;
    const lon = typeof input?.lon === "number" ? input.lon : ctx.lon;
    if (typeof lat !== "number" || typeof lon !== "number") {
      return {
        result: "No coordinates available. Ask the farmer for their city, or tell them to enable location in the app.",
        isError: true,
      };
    }
    try {
      const data =
        input?.period === "today_forecast"
          ? await fetchDailyForecast(lat, lon, ctx.lang)
          : await fetchCurrentWeather(lat, lon, ctx.lang);
      return { result: JSON.stringify(data), isError: false };
    } catch (e: any) {
      return { result: e?.message ?? "Weather lookup failed.", isError: true };
    }
  },

  async get_support_programs(input, ctx) {
    let programs = await listMatchedSupportPrograms(ctx.userId, ctx.lang);
    if (input?.category) {
      const needle = input.category.toString().toLowerCase();
      programs = programs.filter((p: any) => p.category?.toLowerCase() === needle);
    }
    return { result: toToolResult("get_support_programs", programs), isError: false };
  },

  async get_notifications(_input, ctx) {
    const notifications = await listNotifications(ctx.userId);
    return { result: toToolResult("get_notifications", notifications), isError: false };
  },
};
