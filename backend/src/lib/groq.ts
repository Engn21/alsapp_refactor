import Groq from "groq-sdk";

// Lazy singleton - src/index.ts's dotenv.config() runs after ./server (and
// this module's whole import chain) is evaluated, so a module-scope
// `new Groq(...)` would capture `undefined` for the API key. Matches the
// same per-call env-check convention weather.controller.ts uses for
// OPENWEATHER_API_KEY.
let client: Groq | undefined;

export function getGroqClient(): Groq {
  if (!client) {
    const apiKey = process.env.GROQ_API_KEY;
    if (!apiKey) {
      throw Object.assign(new Error("GROQ_API_KEY missing"), { status: 500 });
    }
    // Without an explicit cap a stalled upstream call blocks the request (and
    // the app's send spinner) for the SDK default of 60s x 3 attempts.
    client = new Groq({ apiKey, timeout: 30_000, maxRetries: 1 });
  }
  return client;
}
