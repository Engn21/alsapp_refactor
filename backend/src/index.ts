import path from "path";
import net from "net";
import dotenv from "dotenv";
import { createServer } from "./server";

// Ensure .env from backend folder is loaded regardless of CWD
dotenv.config({ path: path.resolve(__dirname, "../.env") });

const PORT = Number(process.env.PORT || 8080);
// Tüm arayüzlerde dinle: web/emülatör/gerçek cihaz erişsin
const HOST = process.env.HOST || "0.0.0.0";
const PORT_FALLBACK_RANGE = Number(process.env.PORT_FALLBACK_RANGE || 5);

function ensurePortAvailable(
  port: number,
  host: string,
  remainingAttempts: number,
): Promise<number> {
  return new Promise((resolve, reject) => {
    const tester = net.createServer();
    tester.unref();

    tester.once("error", (err: NodeJS.ErrnoException) => {
      if (tester.listening) tester.close();
      if (err.code === "EADDRINUSE" && remainingAttempts > 0) {
        const nextPort = port + 1;
        console.warn(
          `Port ${port} is in use, trying ${nextPort}. You can set PORT to override.`,
        );
        resolve(ensurePortAvailable(nextPort, host, remainingAttempts - 1));
        return;
      }
      reject(err);
    });

    tester.once("listening", () => {
      tester.close(() => resolve(port));
    });

    tester.listen(port, host);
  });
}

ensurePortAvailable(PORT, HOST, PORT_FALLBACK_RANGE)
  .then((resolvedPort) => {
    const app = createServer();
    app.listen(resolvedPort, HOST, () => {
      console.log(`API listening on http://${HOST}:${resolvedPort}`);
    });
  })
  .catch((err) => {
    console.error("Failed to start API server:", err);
    process.exit(1);
  });

// Görünmeyen hataları da konsola düşür
process.on("unhandledRejection", (e) => console.error(e));
process.on("uncaughtException", (e) => console.error(e));
