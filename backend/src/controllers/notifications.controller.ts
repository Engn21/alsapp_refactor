import { Response } from "express";
import { AuthedRequest } from "../middleware/auth";
import {
  listNotifications,
  markNotificationRead,
} from "../lib/notifications";

export async function listAll(req: AuthedRequest, res: Response) {
  const owner = req.user?.id;
  const items = await listNotifications(owner);
  res.json(items);
}

export async function markRead(req: AuthedRequest, res: Response) {
  const { id } = req.params;
  if (!id) return res.status(400).json({ error: "id required" });
  await markNotificationRead(req.user?.id, id);
  res.json({ ok: true });
}
