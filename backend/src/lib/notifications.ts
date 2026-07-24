import { Prisma } from "@prisma/client";
import { AuthedUser } from "../middleware/auth";
import { prisma } from "./prisma";

function serialize(notification: {
  id: string;
  userId: string;
  title: string;
  body: string;
  titleKey: string | null;
  titleParams: Prisma.JsonValue | null;
  bodyKey: string | null;
  bodyParams: Prisma.JsonValue | null;
  category: string | null;
  metadata: Prisma.JsonValue | null;
  read: boolean;
  createdAt: Date;
}) {
  return {
    id: notification.id,
    owner: notification.userId,
    // Plain-text fallback (fixed language) for old clients/rows.
    title: notification.title,
    body: notification.body,
    // Preferred rendering path: the client looks these up via its own
    // translation table so the notification reads correctly in whatever
    // language the viewer currently has selected.
    titleKey: notification.titleKey ?? undefined,
    titleParams: notification.titleParams ?? undefined,
    bodyKey: notification.bodyKey ?? undefined,
    bodyParams: notification.bodyParams ?? undefined,
    category: notification.category ?? undefined,
    metadata: notification.metadata ?? undefined,
    read: notification.read,
    createdAt: notification.createdAt.toISOString(),
  };
}

export async function pushNotification(params: {
  owner: string;
  title: string;
  body: string;
  titleKey?: string;
  titleParams?: Record<string, unknown>;
  bodyKey?: string;
  bodyParams?: Record<string, unknown>;
  category?: string;
  metadata?: Record<string, unknown>;
}) {
  const metadata =
    params.metadata === undefined
      ? undefined
      : (params.metadata as Prisma.InputJsonValue);
  const titleParams =
    params.titleParams === undefined
      ? undefined
      : (params.titleParams as Prisma.InputJsonValue);
  const bodyParams =
    params.bodyParams === undefined
      ? undefined
      : (params.bodyParams as Prisma.InputJsonValue);

  await prisma.notification.create({
    data: {
      userId: params.owner,
      title: params.title,
      body: params.body,
      titleKey: params.titleKey,
      titleParams,
      bodyKey: params.bodyKey,
      bodyParams,
      category: params.category,
      metadata,
    },
  });
}

export async function listNotifications(owner: string | undefined) {
  if (!owner) return [];
  const rows = await prisma.notification.findMany({
    where: { userId: owner },
    orderBy: { createdAt: "desc" },
  });
  return rows.map(serialize);
}

export async function markNotificationRead(
  owner: string | undefined,
  id: string,
) {
  if (!owner) return;
  await prisma.notification.updateMany({
    where: { id, userId: owner },
    data: { read: true },
  });
}

export async function seedNotificationForUser(
  owner: AuthedUser | undefined,
  title: string,
  body: string,
) {
  if (!owner?.id) return;
  await pushNotification({ owner: owner.id, title, body });
}
