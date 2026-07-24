import { NextFunction, Response } from "express";
import { AuthedRequest } from "../middleware/auth";
import { prisma } from "../lib/prisma";
import { pushNotification } from "../lib/notifications";
import { getLivestockThreshold } from "../config/type-thresholds";
import { mergeTypeMetrics, processTypeMetrics } from "../lib/type-metrics";

const { hasOwnProperty } = Object.prototype;

function pickVariant<T = any>(
  source: Record<string, any>,
  keys: string[],
): { provided: boolean; value: T | undefined } {
  for (const key of keys) {
    if (hasOwnProperty.call(source, key)) {
      return { provided: true, value: source[key] as T };
    }
  }
  return { provided: false, value: undefined };
}

function toIso(date: Date | null | undefined) {
  return date ? date.toISOString() : null;
}

function extractMetricMap(entity: any): Record<string, any> {
  const map: Record<string, any> = {};
  const relational = entity?.metrics;
  if (Array.isArray(relational)) {
    for (const item of relational) {
      if (item && typeof item.key === "string" && map[item.key] === undefined) {
        map[item.key] = item.value ?? null;
      }
    }
  }
  const legacy = entity?.customMetrics;
  if (legacy && typeof legacy === "object") {
    for (const [key, value] of Object.entries(legacy)) {
      if (map[key] === undefined) {
        map[key] = value;
      }
    }
  }
  return map;
}

async function replaceLivestockMetrics(
  livestockId: string,
  metrics: Record<string, any>,
): Promise<void> {
  await prisma.livestockMetric.deleteMany({ where: { livestockId } });
  const entries = Object.entries(metrics).filter(
    ([, value]) => value !== undefined && value !== null,
  );
  if (entries.length === 0) return;
  for (const [key, value] of entries) {
    await prisma.livestockMetric.create({
      data: {
        livestockId,
        key,
        value: value as any,
      },
    });
  }
}

function serializeLivestock(item: any) {
  const metricMap = extractMetricMap(item);
  const processed = processTypeMetrics(
    "livestock",
    item.animalType ?? "",
    metricMap,
  );

  return {
    id: item.id,
    userId: item.userId,
    species: item.animalType,
    specificType: item.specificType ?? undefined,
    breed: item.breed ?? undefined,
    birthDate: toIso(item.birthDate),
    notes: item.notes ?? undefined,
    createdAt: toIso(item.createdAt),
    type: "livestock",
    lastMilkAlertAt: toIso(item.lastMilkAlertAt),
    // Type-specific metrics
    weightKg: item.weightKg ?? undefined,
    healthStatus: item.healthStatus ?? undefined,
    dailyFeedKg: item.dailyFeedKg ?? undefined,
    vaccineStatus: item.vaccineStatus ?? undefined,
    lastCheckupDate: toIso(item.lastCheckupDate),
    customMetrics: processed.metrics,
    typeSpecific: processed.metrics,
    trackingHighlights: processed.highlights,
    milkLogs: (item.milkLogs ?? []).map((log: any) => ({
      id: log.id,
      livestockId: log.livestockId,
      measuredAt: toIso(log.measuredAt),
      quantityLiters: log.quantityL,
      fatPercent: log.fatPercent ?? undefined,
      createdAt: toIso(log.createdAt),
    })),
    eggLogs: (item.eggLogs ?? []).map((log: any) => ({
      id: log.id,
      livestockId: log.livestockId,
      measuredAt: toIso(log.measuredAt),
      eggCount: log.eggCount,
      avgWeightGram: log.avgWeightGram ?? undefined,
      createdAt: toIso(log.createdAt),
    })),
    honeyLogs: (item.honeyLogs ?? []).map((log: any) => ({
      id: log.id,
      livestockId: log.livestockId,
      measuredAt: toIso(log.measuredAt),
      amountKg: log.amountKg,
      qualityGrade: log.qualityGrade ?? undefined,
      createdAt: toIso(log.createdAt),
    })),
    woolLogs: (item.woolLogs ?? []).map((log: any) => ({
      id: log.id,
      livestockId: log.livestockId,
      shearedAt: toIso(log.shearedAt),
      amountKg: log.amountKg,
      qualityGrade: log.qualityGrade ?? undefined,
      createdAt: toIso(log.createdAt),
    })),
    weightLogs: (item.weightLogs ?? []).map((log: any) => ({
      id: log.id,
      livestockId: log.livestockId,
      measuredAt: toIso(log.measuredAt),
      weightKg: log.weightKg,
      notes: log.notes ?? undefined,
      createdAt: toIso(log.createdAt),
    })),
  };
}

async function ensureLivestock(ownerId: string, livestockId: string) {
  const record = await prisma.livestock.findFirst({
    where: { id: livestockId, userId: ownerId },
    include: {
      milkLogs: { orderBy: { measuredAt: "desc" } },
      eggLogs: { orderBy: { measuredAt: "desc" } },
      honeyLogs: { orderBy: { measuredAt: "desc" } },
      woolLogs: { orderBy: { shearedAt: "desc" } },
      weightLogs: { orderBy: { measuredAt: "desc" } },
      metrics: true,
    },
  });
  if (!record) {
    const err: any = new Error("Livestock not found");
    err.status = 404;
    throw err;
  }
  return record;
}

async function maybeNotifyMilk(record: any, log: any) {
  const threshold = getLivestockThreshold(record.animalType);
  if (!threshold || !threshold.minDailyMilkL) return;

  const quantityLow = log.quantityL < threshold.minDailyMilkL;
  const fatLow =
    threshold.minMilkFatPercent != null &&
    log.fatPercent != null &&
    log.fatPercent < threshold.minMilkFatPercent;

  if (!quantityLow && !fatLow) return;

  const alreadyAlerted =
    record.lastMilkAlertAt &&
    (record.lastMilkAlertAt as Date).getTime() === log.measuredAt.getTime();

  if (alreadyAlerted) return;

  const reasons: string[] = [];
  const reasonTemplates: { key: string; params: Record<string, unknown> }[] = [];
  if (quantityLow) {
    reasons.push(
      `Miktar: ${log.quantityL.toFixed(1)}L (minimum: ${threshold.minDailyMilkL}L)`,
    );
    reasonTemplates.push({
      key: "notif.reason.milkQuantity",
      params: { value: log.quantityL.toFixed(1), min: threshold.minDailyMilkL },
    });
  }
  if (fatLow) {
    reasons.push(
      `Yağ oranı: ${log.fatPercent?.toFixed(1)}% (minimum: ${threshold.minMilkFatPercent}%)`,
    );
    reasonTemplates.push({
      key: "notif.reason.milkFat",
      params: { value: log.fatPercent?.toFixed(1), min: threshold.minMilkFatPercent },
    });
  }

  const measuredDate = log.measuredAt.toISOString().substring(0, 10);
  await pushNotification({
    owner: record.userId,
    title: `Süt üretimi uyarısı: ${record.animalType}`,
    body: `${measuredDate} tarihli ölçümde ${reasons.join(" ve ")}.`,
    titleKey: "notif.milk.title",
    titleParams: { animalType: record.animalType },
    bodyKey: "notif.milk.body",
    bodyParams: { date: measuredDate, reasons: reasonTemplates },
    category: "livestock",
    metadata: { livestockId: record.id },
  });

  await prisma.livestock.update({
    where: { id: record.id },
    data: { lastMilkAlertAt: log.measuredAt },
  });
  record.lastMilkAlertAt = log.measuredAt;
}

// Eggs are logged per collection (not guaranteed daily - hens skip days
// normally), so this checks a rolling average over the last 7 days rather
// than a single log, and requires a few days of history before judging a
// newly-added bird to avoid false alarms on day one.
async function maybeNotifyEgg(record: any) {
  const threshold = getLivestockThreshold(record.animalType);
  if (!threshold?.minDailyEggs) return;

  const windowDays = 7;
  const minTrackedDays = 3;
  const since = new Date(Date.now() - windowDays * 24 * 60 * 60 * 1000);

  const [logs, earliest] = await Promise.all([
    prisma.eggLog.findMany({
      where: { livestockId: record.id, measuredAt: { gte: since } },
      select: { eggCount: true },
    }),
    prisma.eggLog.findFirst({
      where: { livestockId: record.id },
      orderBy: { measuredAt: "asc" },
      select: { measuredAt: true },
    }),
  ]);
  if (!earliest) return;

  const daysSinceFirst =
    Math.floor((Date.now() - earliest.measuredAt.getTime()) / (24 * 60 * 60 * 1000)) + 1;
  const trackedDays = Math.min(windowDays, daysSinceFirst);
  if (trackedDays < minTrackedDays) return;

  const totalEggs = logs.reduce((sum, l) => sum + l.eggCount, 0);
  const avgPerDay = totalEggs / trackedDays;
  if (avgPerDay >= threshold.minDailyEggs) return;

  const lastAlert = record.lastEggAlertAt as Date | null;
  if (lastAlert && Date.now() - lastAlert.getTime() < 24 * 60 * 60 * 1000) return;

  await pushNotification({
    owner: record.userId,
    title: `Yumurta üretimi uyarısı: ${record.animalType}`,
    body: `Son ${trackedDays} günün ortalaması ${avgPerDay.toFixed(2)} yumurta/gün (minimum: ${threshold.minDailyEggs}).`,
    titleKey: "notif.egg.title",
    titleParams: { animalType: record.animalType },
    bodyKey: "notif.egg.body",
    bodyParams: {
      days: trackedDays,
      avg: avgPerDay.toFixed(2),
      min: threshold.minDailyEggs,
    },
    category: "livestock",
    metadata: { livestockId: record.id },
  });

  const now = new Date();
  await prisma.livestock.update({
    where: { id: record.id },
    data: { lastEggAlertAt: now },
  });
  record.lastEggAlertAt = now;
}

// Honey is harvested a few times a season, not daily, so this checks a
// rolling 365-day total against an annual floor - scaled down for hives
// that haven't been tracked a full year yet - rather than a daily minimum.
async function maybeNotifyHoney(record: any) {
  const threshold = getLivestockThreshold(record.animalType);
  if (!threshold?.minHoneyKgPerYear) return;

  const windowDays = 365;
  const minTrackedDays = 90;
  const since = new Date(Date.now() - windowDays * 24 * 60 * 60 * 1000);

  const [logs, earliest] = await Promise.all([
    prisma.honeyLog.findMany({
      where: { livestockId: record.id, measuredAt: { gte: since } },
      select: { amountKg: true },
    }),
    prisma.honeyLog.findFirst({
      where: { livestockId: record.id },
      orderBy: { measuredAt: "asc" },
      select: { measuredAt: true },
    }),
  ]);
  if (!earliest) return;

  const daysSinceFirst =
    Math.floor((Date.now() - earliest.measuredAt.getTime()) / (24 * 60 * 60 * 1000)) + 1;
  if (daysSinceFirst < minTrackedDays) return;

  const trackedDays = Math.min(windowDays, daysSinceFirst);
  const scaledFloor = threshold.minHoneyKgPerYear * (trackedDays / windowDays);
  const totalKg = logs.reduce((sum, l) => sum + l.amountKg, 0);
  if (totalKg >= scaledFloor) return;

  const lastAlert = record.lastHoneyAlertAt as Date | null;
  const cooldownMs = 30 * 24 * 60 * 60 * 1000; // monthly, not daily - it's a seasonal metric
  if (lastAlert && Date.now() - lastAlert.getTime() < cooldownMs) return;

  await pushNotification({
    owner: record.userId,
    title: `Bal üretimi uyarısı: ${record.animalType}`,
    body: `Son ${trackedDays} günde toplam ${totalKg.toFixed(1)} kg bal (beklenen: ~${scaledFloor.toFixed(1)} kg).`,
    titleKey: "notif.honey.title",
    titleParams: { animalType: record.animalType },
    bodyKey: "notif.honey.body",
    bodyParams: {
      days: trackedDays,
      total: totalKg.toFixed(1),
      expected: scaledFloor.toFixed(1),
    },
    category: "livestock",
    metadata: { livestockId: record.id },
  });

  const now = new Date();
  await prisma.livestock.update({
    where: { id: record.id },
    data: { lastHoneyAlertAt: now },
  });
  record.lastHoneyAlertAt = now;
}

async function maybeNotifyWaterQuality(record: any, metrics: Record<string, any>) {
  if ((record.animalType ?? "").toString().toLowerCase() !== "fish") return;
  const threshold = getLivestockThreshold(record.animalType);
  if (!threshold) return;

  const tempRange = threshold.idealWaterTemperatureC;
  const phRange = threshold.idealWaterPh;
  if (!tempRange && !phRange) return;

  const temp =
    metrics.waterTemperature != null ? Number(metrics.waterTemperature) : null;
  const ph = metrics.waterPh != null ? Number(metrics.waterPh) : null;

  const tempOut =
    tempRange != null &&
    temp != null &&
    Number.isFinite(temp) &&
    (temp < tempRange.min || temp > tempRange.max);
  const phOut =
    phRange != null &&
    ph != null &&
    Number.isFinite(ph) &&
    (ph < phRange.min || ph > phRange.max);

  if (!tempOut && !phOut) return;

  // Avoid re-alerting more than once a day while conditions stay bad.
  const lastAlert = record.lastWaterQualityAlertAt as Date | null;
  if (lastAlert && Date.now() - lastAlert.getTime() < 24 * 60 * 60 * 1000) return;

  const reasons: string[] = [];
  const reasonTemplates: { key: string; params: Record<string, unknown> }[] = [];
  if (tempOut) {
    reasons.push(
      `Su sıcaklığı: ${temp}°C (ideal: ${tempRange!.min}-${tempRange!.max}°C)`,
    );
    reasonTemplates.push({
      key: "notif.reason.waterTemp",
      params: { value: temp, min: tempRange!.min, max: tempRange!.max },
    });
  }
  if (phOut) {
    reasons.push(`Su pH: ${ph} (ideal: ${phRange!.min}-${phRange!.max})`);
    reasonTemplates.push({
      key: "notif.reason.waterPh",
      params: { value: ph, min: phRange!.min, max: phRange!.max },
    });
  }

  await pushNotification({
    owner: record.userId,
    title: `Su kalitesi uyarısı: ${record.animalType}`,
    body: `${reasons.join(" ve ")}.`,
    titleKey: "notif.waterQuality.title",
    titleParams: { animalType: record.animalType },
    bodyKey: "notif.waterQuality.body",
    bodyParams: { reasons: reasonTemplates },
    category: "livestock",
    metadata: { livestockId: record.id },
  });

  const now = new Date();
  await prisma.livestock.update({
    where: { id: record.id },
    data: { lastWaterQualityAlertAt: now },
  });
  record.lastWaterQualityAlertAt = now;
}

export async function listLivestock(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) return res.json([]);

    const animals = await prisma.livestock.findMany({
      where: { userId: owner },
      orderBy: { createdAt: "desc" },
      include: {
        milkLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
        eggLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
        honeyLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
        woolLogs: { orderBy: { shearedAt: "desc" }, take: 5 },
        weightLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
        metrics: true,
      },
    });

    res.json(animals.map(serializeLivestock));
  } catch (err) {
    next(err);
  }
}

export async function getLivestockDetail(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const record = await ensureLivestock(owner, req.params.id);
    res.json(serializeLivestock(record));
  } catch (err) {
    next(err);
  }
}

export async function createLivestock(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const body = req.body ?? {};

    const species = (body.species ?? body.animal_type ?? "").toString().trim();
    if (!species) {
      throw Object.assign(new Error("species is required"), { status: 400 });
    }

    let birthDate: Date | undefined;
    if (body.birthDate ?? body.birthdate) {
      const parsed = new Date(body.birthDate ?? body.birthdate);
      if (Number.isNaN(parsed.valueOf())) {
        throw Object.assign(new Error("birthDate is invalid"), {
          status: 400,
        });
      }
      birthDate = parsed;
    }

    const specificTypeRaw =
      body.specificType ?? body.specific_type ?? body.variant;
    const specificType =
      specificTypeRaw != null && specificTypeRaw !== ""
        ? specificTypeRaw.toString().trim()
        : undefined;

    const weightRaw = body.weight ?? body.weightKg ?? body.weight_kg;
    const weightKg =
      weightRaw != null && weightRaw !== ""
        ? Number.parseFloat(weightRaw.toString())
        : undefined;
    if (weightKg != null && !Number.isFinite(weightKg)) {
      throw Object.assign(new Error("weight is invalid"), { status: 400 });
    }

    const feedRaw =
      body.dailyFeedKg ?? body.dailyFeed ?? body.feed ?? body.feedKg;
    const dailyFeedKg =
      feedRaw != null && feedRaw !== ""
        ? Number.parseFloat(feedRaw.toString())
        : undefined;
    if (dailyFeedKg != null && !Number.isFinite(dailyFeedKg)) {
      throw Object.assign(new Error("dailyFeedKg is invalid"), {
        status: 400,
      });
    }

    let lastCheckupDate: Date | undefined;
    if (body.lastCheckupDate ?? body.last_checkup_date) {
      const parsed = new Date(body.lastCheckupDate ?? body.last_checkup_date);
      if (Number.isNaN(parsed.valueOf())) {
        throw Object.assign(new Error("lastCheckupDate is invalid"), {
          status: 400,
        });
      }
      lastCheckupDate = parsed;
    }

    const typeSpecificInput =
      body.typeSpecific ?? body.customMetrics ?? body.metrics;
    const processedMetrics = processTypeMetrics(
      "livestock",
      species,
      typeSpecificInput,
    );

    const record = await prisma.livestock.create({
      data: {
        userId: owner,
        animalType: species,
        specificType,
        breed: body.breed?.toString(),
        birthDate,
        notes: body.notes?.toString(),
        weightKg: weightKg ?? undefined,
        healthStatus: body.healthStatus?.toString(),
        dailyFeedKg: dailyFeedKg ?? undefined,
        vaccineStatus: body.vaccineStatus?.toString(),
        lastCheckupDate,
        customMetrics:
          Object.keys(processedMetrics.metrics).length > 0
            ? processedMetrics.metrics
            : undefined,
      },
    });

    await replaceLivestockMetrics(record.id, processedMetrics.metrics);
    await maybeNotifyWaterQuality(record, processedMetrics.metrics);

    await pushNotification({
      owner,
      title: `Livestock added: ${species}`,
      body: "We will keep an eye on milk performance and alert you if needed.",
      titleKey: "notif.livestockAdded.title",
      titleParams: { species },
      bodyKey: "notif.livestockAdded.body",
      category: "livestock",
      metadata: { livestockId: record.id },
    });

    const refreshed = await ensureLivestock(owner, record.id);
    res.status(201).json(serializeLivestock(refreshed));
  } catch (err) {
    next(err);
  }
}

export async function updateLivestock(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const body = req.body ?? {};
    const record = await ensureLivestock(owner, req.params.id);

    const data: any = {};

    if (hasOwnProperty.call(body, "notes")) {
      const note = body.notes;
      data.notes =
        note == null || note === "" ? null : note.toString().trim() || null;
    }

    const specificVariant = pickVariant(body, [
      "specificType",
      "specific_type",
      "variant",
    ]);
    if (specificVariant.provided) {
      const val = specificVariant.value;
      data.specificType =
        val == null || val === "" ? null : val.toString().trim() || null;
    }

    if (hasOwnProperty.call(body, "breed")) {
      const breed = body.breed;
      data.breed =
        breed == null || breed === "" ? null : breed.toString().trim() || null;
    }

    const birthVariant = pickVariant(body, ["birthDate", "birthdate"]);
    if (birthVariant.provided) {
      if (birthVariant.value == null || birthVariant.value === "") {
        data.birthDate = null;
      } else {
        const parsed = new Date(birthVariant.value as any);
        if (Number.isNaN(parsed.valueOf())) {
          throw Object.assign(new Error("birthDate is invalid"), {
            status: 400,
          });
        }
        data.birthDate = parsed;
      }
    }

    const weightVariant = pickVariant(body, ["weight", "weightKg", "weight_kg"]);
    if (weightVariant.provided) {
      const value = weightVariant.value;
      if (value == null || value === "") {
        data.weightKg = null;
      } else {
        const parsed = Number.parseFloat(value.toString());
        if (!Number.isFinite(parsed)) {
          throw Object.assign(new Error("weight is invalid"), { status: 400 });
        }
        data.weightKg = parsed;
      }
    }

    const feedVariant = pickVariant(body, [
      "dailyFeedKg",
      "dailyFeed",
      "feed",
      "feedKg",
    ]);
    if (feedVariant.provided) {
      const value = feedVariant.value;
      if (value == null || value === "") {
        data.dailyFeedKg = null;
      } else {
        const parsed = Number.parseFloat(value.toString());
        if (!Number.isFinite(parsed)) {
          throw Object.assign(new Error("dailyFeedKg is invalid"), {
            status: 400,
          });
        }
        data.dailyFeedKg = parsed;
      }
    }

    if (hasOwnProperty.call(body, "healthStatus")) {
      const val = body.healthStatus;
      data.healthStatus =
        val == null || val === "" ? null : val.toString().trim() || null;
    }

    if (hasOwnProperty.call(body, "vaccineStatus")) {
      const val = body.vaccineStatus;
      data.vaccineStatus =
        val == null || val === "" ? null : val.toString().trim() || null;
    }

    const checkupVariant = pickVariant(body, [
      "lastCheckupDate",
      "last_checkup_date",
    ]);
    if (checkupVariant.provided) {
      if (checkupVariant.value == null || checkupVariant.value === "") {
        data.lastCheckupDate = null;
      } else {
        const parsed = new Date(checkupVariant.value as any);
        if (Number.isNaN(parsed.valueOf())) {
          throw Object.assign(new Error("lastCheckupDate is invalid"), {
            status: 400,
          });
        }
        data.lastCheckupDate = parsed;
      }
    }

    const typeSpecificVariant = pickVariant(body, [
      "typeSpecific",
      "customMetrics",
      "metrics",
    ]);
    let mergedMetrics: Record<string, any> | null = null;
    if (typeSpecificVariant.provided) {
      const merged = mergeTypeMetrics(
        "livestock",
        record.animalType,
        extractMetricMap(record),
        typeSpecificVariant.value,
      );
      mergedMetrics = merged.metrics;
      data.customMetrics = merged.metrics;
    }

    if (Object.keys(data).length === 0 && mergedMetrics == null) {
      return res.json(serializeLivestock(record));
    }

    await prisma.livestock.update({
      where: { id: record.id },
      data,
    });

    if (mergedMetrics) {
      await replaceLivestockMetrics(record.id, mergedMetrics);
      await maybeNotifyWaterQuality(record, mergedMetrics);
    }

    const refreshed = await ensureLivestock(owner, record.id);
    res.json(serializeLivestock(refreshed));
  } catch (err) {
    next(err);
  }
}

export async function deleteLivestock(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    await ensureLivestock(owner, req.params.id);
    await prisma.livestock.delete({ where: { id: req.params.id } });
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

export async function recordMilkData(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const record = await ensureLivestock(owner, req.params.id);

    const quantity = Number.parseFloat(
      (req.body?.quantity ?? req.body?.liters ?? req.body?.amount ?? "").toString(),
    );
    if (!Number.isFinite(quantity) || quantity <= 0) {
      throw Object.assign(new Error("quantity must be positive"), {
        status: 400,
      });
    }

    const measuredAt = req.body?.date ? new Date(req.body.date) : new Date();
    if (Number.isNaN(measuredAt.valueOf())) {
      throw Object.assign(new Error("date is invalid"), { status: 400 });
    }

    const fat = req.body?.fat ?? req.body?.fatPercent;
    const fatPercent =
      fat != null && fat !== "" ? Number.parseFloat(fat.toString()) : undefined;

    const log = await prisma.milkLog.create({
      data: {
        livestockId: record.id,
        measuredAt,
        quantityL: quantity,
        fatPercent,
      },
    });

    await maybeNotifyMilk(record, {
      ...log,
      quantityL: quantity,
      fatPercent,
      measuredAt,
    });

    res.json({
      ok: true,
      log: {
        id: log.id,
        livestockId: log.livestockId,
        measuredAt: log.measuredAt.toISOString(),
        quantityLiters: log.quantityL,
        fatPercent: log.fatPercent ?? undefined,
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function recordEggData(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const record = await ensureLivestock(owner, req.params.id);

    const eggCount = Number.parseInt(
      (req.body?.eggCount ?? req.body?.count ?? "").toString(),
      10,
    );
    if (!Number.isFinite(eggCount) || eggCount < 0) {
      throw Object.assign(new Error("eggCount must be a non-negative integer"), {
        status: 400,
      });
    }

    const measuredAt = req.body?.date ? new Date(req.body.date) : new Date();
    if (Number.isNaN(measuredAt.valueOf())) {
      throw Object.assign(new Error("date is invalid"), { status: 400 });
    }

    const weight = req.body?.avgWeightGram ?? req.body?.avgWeight;
    const avgWeightGram =
      weight != null && weight !== "" ? Number.parseFloat(weight.toString()) : undefined;

    const log = await prisma.eggLog.create({
      data: {
        livestockId: record.id,
        measuredAt,
        eggCount,
        avgWeightGram,
      },
    });

    await maybeNotifyEgg(record);

    res.json({
      ok: true,
      log: {
        id: log.id,
        livestockId: log.livestockId,
        measuredAt: log.measuredAt.toISOString(),
        eggCount: log.eggCount,
        avgWeightGram: log.avgWeightGram ?? undefined,
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function recordHoneyData(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const record = await ensureLivestock(owner, req.params.id);

    const amount = Number.parseFloat(
      (req.body?.amount ?? req.body?.amountKg ?? "").toString(),
    );
    if (!Number.isFinite(amount) || amount <= 0) {
      throw Object.assign(new Error("amount must be positive"), { status: 400 });
    }

    const measuredAt = req.body?.date ? new Date(req.body.date) : new Date();
    if (Number.isNaN(measuredAt.valueOf())) {
      throw Object.assign(new Error("date is invalid"), { status: 400 });
    }

    const quality = req.body?.qualityGrade ?? req.body?.quality;
    const qualityGrade =
      quality != null && quality !== "" ? quality.toString().trim() : undefined;

    const log = await prisma.honeyLog.create({
      data: {
        livestockId: record.id,
        measuredAt,
        amountKg: amount,
        qualityGrade,
      },
    });

    await maybeNotifyHoney(record);

    res.json({
      ok: true,
      log: {
        id: log.id,
        livestockId: log.livestockId,
        measuredAt: log.measuredAt.toISOString(),
        amountKg: log.amountKg,
        qualityGrade: log.qualityGrade ?? undefined,
      },
    });
  } catch (err) {
    next(err);
  }
}
