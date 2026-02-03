import { NextFunction, Request, Response } from "express";

// Named export (server.ts içinde: import { errorHandler } from "./middleware/error")
export function errorHandler(
  err: any,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  // Konsola tam hata düşsün
  console.error(err);
  const status = typeof err?.status === "number" ? err.status : 500;
  const message = err?.message || "Internal Server Error";
  res.status(status).json({ message });
}
