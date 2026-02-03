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
  if (quantityLow) {
    reasons.push(
      `Miktar: ${log.quantityL.toFixed(1)}L (minimum: ${threshold.minDailyMilkL}L)`,
    );
  }
  if (fatLow) {
    reasons.push(
      `Yağ oranı: ${log.fatPercent?.toFixed(1)}% (minimum: ${threshold.minMilkFatPercent}%)`,
    );
  }

  await pushNotification({
    owner: record.userId,
    title: `Süt üretimi uyarısı: ${record.animalType}`,
    body: `${log.measuredAt.toISOString().substring(0, 10)} tarihli ölçümde ${reasons.join(" ve ")}.`,
    category: "livestock",
    metadata: { livestockId: record.id },
  });

  await prisma.livestock.update({
    where: { id: record.id },
    data: { lastMilkAlertAt: log.measuredAt },
  });
  record.lastMilkAlertAt = log.measuredAt;
}

export async function listLivestock(req: AuthedRequest, res: Response) {
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

    await pushNotification({
      owner,
      title: `Livestock added: ${species}`,
      body: "We will keep an eye on milk performance and alert you if needed.",
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
