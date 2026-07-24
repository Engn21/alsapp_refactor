import type { ChatCompletionTool } from "groq-sdk/resources/chat/completions";

// Five read-only tools the assistant can call. Each is always scoped
// server-side to the authenticated user (see toolExecutors.ts) - the
// model never supplies a user/owner id itself. Descriptions are
// deliberately prescriptive about *when* to call each tool, which
// measurably improves should-call behavior.
export const ASSISTANT_TOOLS: ChatCompletionTool[] = [
  {
    type: "function",
    function: {
      name: "get_crops",
      description:
        "Get the logged-in farmer's crop records, including recent spray, harvest, and quality-log history. Call this whenever the user asks about their crops, planting or harvest status, spray schedule, or crop quality/health. Never guess crop data without calling this first.",
      parameters: {
        type: "object",
        properties: {
          cropType: {
            type: "string",
            description:
              "Optional case-insensitive filter, e.g. 'wheat'. Omit to get all crops.",
          },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_livestock",
      description:
        "Get the farmer's livestock records, including recent milk, egg, honey, wool, and weight logs. Call this whenever the user asks about their animals, herd/flock status, or production (milk, eggs, honey, wool). Never guess livestock data without calling this first.",
      parameters: {
        type: "object",
        properties: {
          species: {
            type: "string",
            description:
              "Optional case-insensitive filter, e.g. 'cow'. Omit to get all livestock.",
          },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_weather",
      description:
        "Get current or today's forecast weather for the farmer's location. If you don't already have coordinates from context, ask the farmer for their city or tell them to enable location in the app, then call this tool once coordinates are known.",
      parameters: {
        type: "object",
        properties: {
          lat: { type: "number", description: "Latitude, if known from the conversation." },
          lon: { type: "number", description: "Longitude, if known from the conversation." },
          period: {
            type: "string",
            enum: ["current", "today_forecast"],
            description: "'current' for right-now conditions, 'today_forecast' for today's min/max/rain outlook.",
          },
        },
        required: ["period"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_support_programs",
      description:
        "Get government/agricultural support programs relevant to the farmer's current crops and livestock, including eligibility, amounts, and application deadlines. Call this whenever the user asks about subsidies, grants, or support programs they may qualify for.",
      parameters: {
        type: "object",
        properties: {
          category: {
            type: "string",
            description:
              "Optional filter, e.g. 'bitkisel' (crop), 'hayvansal' (livestock), 'kredi' (credit). Omit to get all matched programs.",
          },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_notifications",
      description:
        "Get the farmer's recent app notifications and alerts (production warnings, spray reminders, support deadlines). Call this when the user asks about recent alerts or what needs their attention.",
      parameters: {
        type: "object",
        properties: {},
      },
    },
  },
];
