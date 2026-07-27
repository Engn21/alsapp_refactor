import { Prisma } from "@prisma/client";
import { AuthedUser } from "../middleware/auth";
import { prisma } from "./prisma";
import { getFirebaseMessaging } from "./firebase";

// Backend-side copy of the Turkish notif.* templates from
// frontend/lib/l10n/app_localizations.dart, used ONLY to render plain-text
// push payloads (FCM notifications are plain strings, not key+params).
// The in-app inbox stays fully dynamic via the client's own context.tr() -
// this is a known, deliberate limitation: push banner text is frozen to
// Turkish at delivery time regardless of the viewer's selected language.
const PUSH_TEMPLATES: Record<string, string> = {
  "notif.milk.title": "Süt üretimi uyarısı: {animalType}",
  "notif.milk.body": "{date} tarihli ölçümde {reasons}.",
  "notif.egg.title": "Yumurta üretimi uyarısı: {animalType}",
  "notif.egg.body":
    "Son {days} günün ortalaması {avg} yumurta/gün (minimum: {min}).",
  "notif.honey.title": "Bal üretimi uyarısı: {animalType}",
  "notif.honey.body":
    "Son {days} günde toplam {total} kg bal (beklenen: ~{expected} kg).",
  "notif.waterQuality.title": "Su kalitesi uyarısı: {animalType}",
  "notif.waterQuality.body": "{reasons}.",
  "notif.livestockAdded.title": "Hayvan eklendi: {species}",
  "notif.livestockAdded.body":
    "Süt performansını takip edecek, gerekirse sizi uyaracağız.",
  "notif.spray.title": "{cropType} için ilaçlama zamanı geldi",
  "notif.spray.body": "{cropType} için {pesticide} uygulama zamanı geldi.",
  "notif.spray.bodyGeneric":
    "{cropType} için planlanan tedavi uygulama zamanı geldi.",
  "notif.cropAdded.title": "Yeni ürün eklendi: {cropType}",
  "notif.cropAdded.body":
    "{cropType} için ilaçlama takvimi ve verim takip edilecek.",
  "notif.lowYield.title": "Düşük verim: {cropType}",
  "notif.lowYield.body":
    "Hasat verimi {yield} t/ha, beklenen minimum {min} t/ha.",
  "notif.qualityWarning.title": "Kalite uyarısı: {cropType}",
  "notif.qualityWarning.body":
    "Ölçüm sonuçları ideal aralığın dışında: {reasons}",
  "notif.supportDeadline.title": "Destek süresi yaklaşıyor: {title}",
  "notif.supportDeadline.body":
    "Başvuru için {days} gün kaldı (son tarih: {deadline}).",
  "notif.reason.milkQuantity": "miktar {value}L (minimum: {min}L)",
  "notif.reason.milkFat": "yağ oranı %{value} (minimum: %{min})",
  "notif.reason.waterTemp": "su sıcaklığı {value}°C (ideal: {min}-{max}°C)",
  "notif.reason.waterPh": "su pH {value} (ideal: {min}-{max})",
  "notif.reason.protein": "protein %{value} (ideal: %{min}-%{max})",
  "notif.reason.moisture": "nem %{value} (ideal: %{min}-%{max})",
  "notif.reason.sugar": "şeker %{value} (ideal: %{min}-%{max})",
  "notif.reason.oil": "yağ %{value} (ideal: %{min}-%{max})",
  "notif.reasonSeparator": " ve ",
};

function substitute(template: string, params: Record<string, unknown>) {
  let result = template;
  for (const [key, value] of Object.entries(params)) {
    result = result.split(`{${key}}`).join(String(value ?? ""));
  }
  return result;
}

// Resolves a titleKey/bodyKey + params pair into plain text for a push
// payload. Compound notifications (milk, water quality, quality warning)
// carry a `reasons` array of {key, params} sub-templates in bodyParams,
// same structure the frontend's NotificationItem.localizedBody() reads.
function renderPushText(
  key: string | null | undefined,
  params: Prisma.JsonValue | null | undefined,
  fallback: string,
): string {
  if (!key) return fallback;
  const template = PUSH_TEMPLATES[key];
  if (!template) return fallback;

  const paramsObj = { ...((params as Record<string, unknown>) ?? {}) };
  const reasons = paramsObj.reasons;
  if (Array.isArray(reasons)) {
    const separator = PUSH_TEMPLATES["notif.reasonSeparator"];
    paramsObj.reasons = reasons
      .map((r: any) => {
        const reasonTemplate = PUSH_TEMPLATES[r?.key];
        if (!reasonTemplate) return null;
        return substitute(reasonTemplate, r?.params ?? {});
      })
      .filter((s): s is string => s !== null)
      .join(separator);
  }
  return substitute(template, paramsObj);
}

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

  const row = await prisma.notification.create({
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

  // Push delivery is best-effort: never let a bad/expired token or an FCM
  // outage affect the notification write itself, so this is deliberately
  // NOT awaited and its own errors are swallowed here, not thrown.
  void sendPushForNotification(row).catch((err) => {
    console.error("[push] send failed:", err?.message ?? err);
  });

  return row;
}

async function sendPushForNotification(row: {
  userId: string;
  title: string;
  body: string;
  titleKey: string | null;
  titleParams: Prisma.JsonValue | null;
  bodyKey: string | null;
  bodyParams: Prisma.JsonValue | null;
  metadata: Prisma.JsonValue | null;
}) {
  const tokens = await prisma.deviceToken.findMany({
    where: { userId: row.userId },
    select: { token: true },
  });
  if (tokens.length === 0) return;

  const title = renderPushText(row.titleKey, row.titleParams, row.title);
  const body = renderPushText(row.bodyKey, row.bodyParams, row.body);

  // FCM data payload values must all be strings.
  const metadata = (row.metadata as Record<string, unknown> | null) ?? {};
  const data = Object.fromEntries(
    Object.entries(metadata).map(([k, v]) => [k, String(v)]),
  );

  const messaging = getFirebaseMessaging();
  const response = await messaging.sendEachForMulticast({
    tokens: tokens.map((t) => t.token),
    notification: { title, body },
    data,
  });

  const staleTokens = response.responses
    .map((r: { success: boolean; error?: { code: string } }, i: number) =>
      !r.success && isUnregisteredError(r.error?.code)
        ? tokens[i].token
        : null,
    )
    .filter((t: string | null): t is string => t !== null);
  if (staleTokens.length > 0) {
    await prisma.deviceToken.deleteMany({
      where: { token: { in: staleTokens } },
    });
  }
}

function isUnregisteredError(code: string | undefined) {
  return (
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token"
  );
}

export async function upsertDeviceToken(
  userId: string,
  token: string,
  platform?: string,
) {
  await prisma.deviceToken.upsert({
    where: { token },
    create: { userId, token, platform: platform ?? "web" },
    update: { userId, lastSeenAt: new Date() },
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
