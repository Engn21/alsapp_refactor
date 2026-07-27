import { NextFunction, Response } from "express";
import { AuthedRequest } from "../middleware/auth";
import {
  listNotifications,
  markNotificationRead,
  upsertDeviceToken,
} from "../lib/notifications";

export async function listAll(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    const items = await listNotifications(owner);
    res.json(items);
  } catch (err) {
    next(err);
  }
}

export async function markRead(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const { id } = req.params;
    if (!id) return res.status(400).json({ error: "id required" });
    await markNotificationRead(req.user?.id, id);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
}

export async function registerDevice(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const { token, platform } = req.body ?? {};
    if (!token) return res.status(400).json({ error: "token required" });
    await upsertDeviceToken(owner, token, platform);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
}
