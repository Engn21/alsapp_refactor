"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.pushNotification = pushNotification;
exports.listNotifications = listNotifications;
exports.markNotificationRead = markNotificationRead;
exports.seedNotificationForUser = seedNotificationForUser;
const prisma_1 = require("./prisma");
function serialize(notification) {
    return {
        id: notification.id,
        owner: notification.userId,
        title: notification.title,
        body: notification.body,
        category: notification.category ?? undefined,
        metadata: notification.metadata ?? undefined,
        read: notification.read,
        createdAt: notification.createdAt.toISOString(),
    };
}
async function pushNotification(params) {
    const metadata = params.metadata === undefined
        ? undefined
        : params.metadata;
    await prisma_1.prisma.notification.create({
        data: {
            userId: params.owner,
            title: params.title,
            body: params.body,
            category: params.category,
            metadata,
        },
    });
}
async function listNotifications(owner) {
    if (!owner)
        return [];
    const rows = await prisma_1.prisma.notification.findMany({
        where: { userId: owner },
        orderBy: { createdAt: "desc" },
    });
    return rows.map(serialize);
}
async function markNotificationRead(owner, id) {
    if (!owner)
        return;
    await prisma_1.prisma.notification.updateMany({
        where: { id, userId: owner },
        data: { read: true },
    });
}
async function seedNotificationForUser(owner, title, body) {
    if (!owner?.id)
        return;
    await pushNotification({ owner: owner.id, title, body });
}
