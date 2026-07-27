import { initializeApp, cert, App } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";

// Lazy singleton - src/index.ts's dotenv.config() runs after ./server (and
// this module's whole import chain) is evaluated, so a module-scope
// `initializeApp(...)` would capture `undefined` for the service account.
// Matches the same per-call env-check convention groq.ts uses.
let app: App | undefined;

export function getFirebaseMessaging() {
  if (!app) {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
    if (!raw) {
      throw Object.assign(
        new Error("FIREBASE_SERVICE_ACCOUNT_BASE64 missing"),
        { status: 500 },
      );
    }
    const json = JSON.parse(Buffer.from(raw, "base64").toString("utf8"));
    app = initializeApp({ credential: cert(json) });
  }
  return getMessaging(app);
}
