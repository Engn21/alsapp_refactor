"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listAll = listAll;
exports.markRead = markRead;
const notifications_1 = require("../lib/notifications");
async function listAll(req, res) {
    const owner = req.user?.id;
    const items = await (0, notifications_1.listNotifications)(owner);
    res.json(items);
}
async function markRead(req, res) {
    const { id } = req.params;
    if (!id)
        return res.status(400).json({ error: "id required" });
    await (0, notifications_1.markNotificationRead)(req.user?.id, id);
    res.json({ ok: true });
}
