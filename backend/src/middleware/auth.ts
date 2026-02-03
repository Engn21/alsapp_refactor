// src/middleware/auth.ts (senin sürümün)
import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

export interface AuthedUser {
  id: string;
  role: string;
}

export interface AuthedRequest extends Request {
  user?: AuthedUser;
}

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace("Bearer ", "");
  if (!token) return res.status(401).json({ message: "Missing token" });
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as any;
    // payload.sub = user.id, payload.role = role
    if (!payload?.sub) return res.status(401).json({ message: "Invalid token (no subject)" });
    req.user = { id: payload.sub, role: payload.role };
    next();
  } catch {
    res.status(401).json({ message: "Invalid token" });
  }
}
