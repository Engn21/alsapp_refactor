import { NextFunction, Response } from "express";
import { AuthedRequest } from "../middleware/auth";
import { prisma } from "../lib/prisma";
import { pushNotification } from "../lib/notifications";
import { getCropThreshold } from "../config/type-thresholds";
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

const PESTICIDE_INTERVALS: Record<string, number> = {
  fungicide: 14,
  herbicide: 21,
  insecticide: 10,
  foliar: 18,
};

const DEFAULT_SPRAY_INTERVAL = 14;

function normalize(str: string) {
  return str.trim().toLowerCase();
}

function toIso(date: Date | null | undefined) {
  return date ? date.toISOString() : null;
}

function computeNextSprayDue(
  base: Date | null | undefined,
  pesticide: string | null | undefined,
) {
  if (!base) return null;
  const interval =
    PESTICIDE_INTERVALS[normalize(pesticide ?? "")] ?? DEFAULT_SPRAY_INTERVAL;
  const due = new Date(base.getTime());
  due.setUTCDate(due.getUTCDate() + interval);
  return due;
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

async function replaceCropMetrics(
  cropId: string,
  metrics: Record<string, any>,
): Promise<void> {
  await prisma.cropMetric.deleteMany({ where: { cropId } });
  const entries = Object.entries(metrics).filter(
    ([, value]) => value !== undefined && value !== null,
  );
  if (entries.length === 0) return;
  for (const [key, value] of entries) {
    await prisma.cropMetric.create({
      data: {
        cropId,
        key,
        value: value as any,
      },
    });
  }
}

function serializeCrop(crop: any) {
  const metricMap = extractMetricMap(crop);
  const processed = processTypeMetrics(
    "crop",
    crop.cropType ?? "",
    metricMap,
  );

  return {
    id: crop.id,
    userId: crop.userId,
    cropType: crop.cropType,
    specificType: crop.specificType ?? undefined,
    plantingDate: toIso(crop.plantingDate),
    harvestDate: toIso(crop.harvestDate),
    notes: crop.notes ?? undefined,
    areaHectares: crop.areaHectares ?? undefined,
    pesticide: crop.pesticide ?? undefined,
    nextSprayDueAt: toIso(crop.nextSprayDueAt),
    lastSprayAlertAt: toIso(crop.lastSprayAlertAt),
    createdAt: toIso(crop.createdAt),
    type: "crop",
    // Type-specific metrics
    proteinPercent: crop.proteinPercent ?? undefined,
    moisturePercent: crop.moisturePercent ?? undefined,
    sugarPercent: crop.sugarPercent ?? undefined,
    oilPercent: crop.oilPercent ?? undefined,
    healthStatus: crop.healthStatus ?? undefined,
    diseaseNotes: crop.diseaseNotes ?? undefined,
    qualityScore: crop.qualityScore ?? undefined,
    customMetrics: processed.metrics,
    typeSpecific: processed.metrics,
    trackingHighlights: processed.highlights,
    sprays: (crop.sprays ?? []).map((s: any) => ({
      id: s.id,
      cropId: s.cropId,
      pesticide: s.pesticide ?? undefined,
      sprayedAt: toIso(s.sprayedAt),
      createdAt: toIso(s.createdAt),
    })),
    harvests: (crop.harvests ?? []).map((h: any) => ({
      id: h.id,
      cropId: h.cropId,
      harvestedAt: toIso(h.harvestedAt),
      amountTon: h.amountTon,
      yieldTonPerHa: h.yieldTonPerHa ?? undefined,
      createdAt: toIso(h.createdAt),
    })),
    qualityLogs: (crop.qualityLogs ?? []).map((q: any) => ({
      id: q.id,
      cropId: q.cropId,
      measuredAt: toIso(q.measuredAt),
      proteinPercent: q.proteinPercent ?? undefined,
      moisturePercent: q.moisturePercent ?? undefined,
      sugarPercent: q.sugarPercent ?? undefined,
      oilPercent: q.oilPercent ?? undefined,
      notes: q.notes ?? undefined,
      createdAt: toIso(q.createdAt),
    })),
  };
}

async function ensureCrop(ownerId: string, cropId: string) {
  const crop = await prisma.crop.findFirst({
    where: { id: cropId, userId: ownerId },
    include: {
      sprays: { orderBy: { sprayedAt: "desc" } },
      harvests: { orderBy: { harvestedAt: "desc" } },
      qualityLogs: { orderBy: { measuredAt: "desc" } },
      metrics: true,
    },
  });
  if (!crop) {
    const err: any = new Error("Crop not found");
    err.status = 404;
    throw err;
  }
  return crop;
}

async function maybeNotifySprayDue(crop: any) {
  if (!crop.nextSprayDueAt) return;
  const due = crop.nextSprayDueAt as Date;
  const alreadyAlerted =
    crop.lastSprayAlertAt &&
    (crop.lastSprayAlertAt as Date).getTime() === due.getTime();
  if (alreadyAlerted) return;
  if (due.getTime() <= Date.now()) {
    await pushNotification({
      owner: crop.userId,
      title: `Spray due for ${crop.cropType}`,
      body: `It's time to apply ${
        crop.pesticide ?? "the planned treatment"
      } to ${crop.cropType}.`,
      category: "crop",
      metadata: { cropId: crop.id },
    });
    await prisma.crop.update({
      where: { id: crop.id },
      data: { lastSprayAlertAt: due },
    });
    crop.lastSprayAlertAt = due;
  }
}

export async function listCrops(req: AuthedRequest, res: Response) {
  const owner = req.user?.id;
  if (!owner) return res.json([]);

  const crops = await prisma.crop.findMany({
    where: { userId: owner },
    orderBy: { createdAt: "desc" },
    include: {
      sprays: { orderBy: { sprayedAt: "desc" }, take: 5 },
      harvests: { orderBy: { harvestedAt: "desc" }, take: 5 },
      qualityLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
      metrics: true,
    },
  });

  await Promise.all(crops.map(maybeNotifySprayDue));

  res.json(crops.map(serializeCrop));
}

export async function getCropDetail(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const crop = await ensureCrop(owner, req.params.id);
    await maybeNotifySprayDue(crop);
    res.json(serializeCrop(crop));
  } catch (err) {
    next(err);
  }
}

export async function createCrop(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const body = req.body ?? {};

    const cropType = (body.cropType ?? body.crop_type ?? "").toString().trim();
    if (!cropType) {
      throw Object.assign(new Error("cropType is required"), { status: 400 });
    }

    const plantingDate = new Date(body.plantingDate ?? body.planting_date);
    if (Number.isNaN(plantingDate.valueOf())) {
      throw Object.assign(new Error("plantingDate is invalid"), { status: 400 });
    }

    let harvestDate: Date | undefined;
    if (body.harvestDate ?? body.harvest_date) {
      const parsed = new Date(body.harvestDate ?? body.harvest_date);
      if (Number.isNaN(parsed.valueOf())) {
        throw Object.assign(new Error("harvestDate is invalid"), {
          status: 400,
        });
      }
      harvestDate = parsed;
    }

    const specificVariant = pickVariant(body, [
      "specificType",
      "specific_type",
      "varietyName",
      "variant",
    ]);
    const specificType =
      specificVariant.provided && specificVariant.value != null
        ? specificVariant.value.toString().trim()
        : undefined;

    const area = body.area ?? body.areaHectares ?? body.area_hectares;
    const areaHectares =
      area != null && area !== ""
        ? Number.parseFloat(area.toString())
        : undefined;

    const pesticide = (body.pesticide ?? body.pesticideType ?? "").toString().trim();

    const nextSprayDueAt = pesticide
      ? computeNextSprayDue(plantingDate, pesticide)
      : null;

    const typeSpecificInput =
      body.typeSpecific ?? body.customMetrics ?? body.metrics;
    const processedMetrics = processTypeMetrics(
      "crop",
      cropType,
      typeSpecificInput,
    );

    const created = await prisma.crop.create({
      data: {
        userId: owner,
        cropType,
        specificType,
        plantingDate,
        harvestDate,
        notes: body.notes?.toString(),
        areaHectares,
        pesticide: pesticide || null,
        nextSprayDueAt,
        customMetrics:
          Object.keys(processedMetrics.metrics).length > 0
            ? processedMetrics.metrics
            : undefined,
      },
    });

    await replaceCropMetrics(created.id, processedMetrics.metrics);

    await pushNotification({
      owner,
      title: `New crop added: ${cropType}`,
      body: `We will monitor ${cropType} for spray schedules and yields.`,
      category: "crop",
      metadata: { cropId: created.id },
    });

    const refreshed = await ensureCrop(owner, created.id);
    res.status(201).json(serializeCrop(refreshed));
  } catch (err) {
    next(err);
  }
}

export async function updateCrop(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const body = req.body ?? {};
    const crop = await ensureCrop(owner, req.params.id);

    const data: any = {};

    if (hasOwnProperty.call(body, "notes")) {
      const note = body.notes;
      data.notes =
        note == null || note === "" ? null : note.toString().trim() || null;
    }

    const specificVariant = pickVariant(body, [
      "specificType",
      "specific_type",
      "varietyName",
      "variant",
    ]);
    if (specificVariant.provided) {
      const val = specificVariant.value;
      data.specificType =
        val == null || val === "" ? null : val.toString().trim() || null;
    }

    const areaVariant = pickVariant(body, [
      "area",
      "areaHectares",
      "area_hectares",
    ]);
    if (areaVariant.provided) {
      const val = areaVariant.value;
      if (val == null || val === "") {
        data.areaHectares = null;
      } else {
        const parsed = Number.parseFloat(val.toString());
        if (!Number.isFinite(parsed)) {
          throw Object.assign(new Error("area is invalid"), { status: 400 });
        }
        data.areaHectares = parsed;
      }
    }

    const plantingVariant = pickVariant(body, [
      "plantingDate",
      "planting_date",
    ]);
    if (plantingVariant.provided) {
      if (plantingVariant.value == null || plantingVariant.value === "") {
        throw Object.assign(
          new Error("plantingDate cannot be cleared"),
          { status: 400 },
        );
      }
      const parsed = new Date(plantingVariant.value as any);
      if (Number.isNaN(parsed.valueOf())) {
        throw Object.assign(new Error("plantingDate is invalid"), {
          status: 400,
        });
      }
      data.plantingDate = parsed;
    }

    const harvestVariant = pickVariant(body, ["harvestDate", "harvest_date"]);
    if (harvestVariant.provided) {
      if (harvestVariant.value == null || harvestVariant.value === "") {
        data.harvestDate = null;
      } else {
        const parsed = new Date(harvestVariant.value as any);
        if (Number.isNaN(parsed.valueOf())) {
          throw Object.assign(new Error("harvestDate is invalid"), {
            status: 400,
          });
        }
        data.harvestDate = parsed;
      }
    }

    if (hasOwnProperty.call(body, "pesticide") || hasOwnProperty.call(body, "pesticideType")) {
      const raw = body.pesticide ?? body.pesticideType;
      data.pesticide =
        raw == null || raw === "" ? null : raw.toString().trim() || null;
    }

    const nextSprayVariant = pickVariant(body, [
      "nextSprayDueAt",
      "next_spray_due_at",
    ]);
    if (nextSprayVariant.provided) {
      if (nextSprayVariant.value == null || nextSprayVariant.value === "") {
        data.nextSprayDueAt = null;
      } else {
        const parsed = new Date(nextSprayVariant.value as any);
        if (Number.isNaN(parsed.valueOf())) {
          throw Object.assign(new Error("nextSprayDueAt is invalid"), {
            status: 400,
          });
        }
        data.nextSprayDueAt = parsed;
      }
    }

    if (hasOwnProperty.call(body, "healthStatus")) {
      const val = body.healthStatus;
      data.healthStatus =
        val == null || val === "" ? null : val.toString().trim() || null;
    }

    if (hasOwnProperty.call(body, "diseaseNotes")) {
      const val = body.diseaseNotes;
      data.diseaseNotes =
        val == null || val === "" ? null : val.toString().trim() || null;
    }

    if (hasOwnProperty.call(body, "qualityScore")) {
      const val = body.qualityScore;
      if (val == null || val === "") {
        data.qualityScore = null;
      } else {
        const parsed = Number.parseInt(val.toString(), 10);
        if (!Number.isFinite(parsed)) {
          throw Object.assign(new Error("qualityScore is invalid"), {
            status: 400,
          });
        }
        data.qualityScore = parsed;
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
        "crop",
        crop.cropType,
        extractMetricMap(crop),
        typeSpecificVariant.value,
      );
      mergedMetrics = merged.metrics;
      data.customMetrics = merged.metrics;
    }

    if (Object.keys(data).length === 0 && mergedMetrics == null) {
      return res.json(serializeCrop(crop));
    }

    await prisma.crop.update({
      where: { id: crop.id },
      data,
    });

    if (mergedMetrics) {
      await replaceCropMetrics(crop.id, mergedMetrics);
    }

    const refreshed = await ensureCrop(owner, crop.id);
    res.json(serializeCrop(refreshed));
  } catch (err) {
    next(err);
  }
}

export async function deleteCrop(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    await ensureCrop(owner, req.params.id);
    await prisma.crop.delete({ where: { id: req.params.id } });
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

export async function recordCropSpray(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const crop = await ensureCrop(owner, req.params.id);

    const sprayedAt = req.body?.date ? new Date(req.body.date) : new Date();
    if (Number.isNaN(sprayedAt.valueOf())) {
      throw Object.assign(new Error("date is invalid"), { status: 400 });
    }

    const pesticide =
      (req.body?.pesticide ?? "").toString().trim() || crop.pesticide || null;

    const spray = await prisma.cropSpray.create({
      data: {
        cropId: crop.id,
        sprayedAt,
        pesticide,
      },
    });

    const nextDue = computeNextSprayDue(sprayedAt, pesticide ?? crop.pesticide);

    await prisma.crop.update({
      where: { id: crop.id },
      data: {
        pesticide,
        nextSprayDueAt: nextDue,
        lastSprayAlertAt: null,
      },
    });

    res.json({
      ok: true,
      spray: {
        id: spray.id,
        cropId: spray.cropId,
        pesticide: spray.pesticide ?? undefined,
        sprayedAt: spray.sprayedAt.toISOString(),
      },
      nextSprayDueAt: nextDue ? nextDue.toISOString() : null,
    });
  } catch (err) {
    next(err);
  }
}

export async function recordCropHarvest(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const crop = await ensureCrop(owner, req.params.id);
    const amount = Number.parseFloat(
      (req.body?.amount ?? req.body?.amountTon ?? req.body?.yield ?? "").toString(),
    );
    if (!Number.isFinite(amount) || amount <= 0) {
      throw Object.assign(new Error("amount must be positive"), {
        status: 400,
      });
    }

    const harvestedAt = req.body?.date ? new Date(req.body.date) : new Date();
    if (Number.isNaN(harvestedAt.valueOf())) {
      throw Object.assign(new Error("date is invalid"), { status: 400 });
    }

    const yieldPerHa =
      crop.areaHectares && crop.areaHectares > 0
        ? amount / crop.areaHectares
        : null;

    const harvest = await prisma.cropHarvest.create({
      data: {
        cropId: crop.id,
        harvestedAt,
        amountTon: amount,
        yieldTonPerHa: yieldPerHa,
      },
    });

    await prisma.crop.update({
      where: { id: crop.id },
      data: { harvestDate: harvestedAt },
    });

    const threshold = getCropThreshold(crop.cropType);
    if (
      threshold != null &&
      yieldPerHa != null &&
      yieldPerHa < threshold.minYieldTonPerHa
    ) {
      await pushNotification({
        owner: crop.userId,
        title: `Düşük verim: ${crop.cropType}`,
        body: `Hasat verimi ${yieldPerHa.toFixed(2)} t/ha, beklenen minimum ${threshold.minYieldTonPerHa} t/ha.`,
        category: "crop",
        metadata: { cropId: crop.id },
      });
    }

    res.json({
      ok: true,
      harvest: {
        id: harvest.id,
        cropId: harvest.cropId,
        harvestedAt: harvest.harvestedAt.toISOString(),
        amountTon: harvest.amountTon,
        yieldTonPerHa: harvest.yieldTonPerHa ?? undefined,
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function recordCropQuality(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });
    const crop = await ensureCrop(owner, req.params.id);

    const measuredAt = req.body?.date ? new Date(req.body.date) : new Date();
    if (Number.isNaN(measuredAt.valueOf())) {
      throw Object.assign(new Error("date is invalid"), { status: 400 });
    }

    const proteinPercent = req.body?.proteinPercent
      ? Number.parseFloat(req.body.proteinPercent)
      : null;
    const moisturePercent = req.body?.moisturePercent
      ? Number.parseFloat(req.body.moisturePercent)
      : null;
    const sugarPercent = req.body?.sugarPercent
      ? Number.parseFloat(req.body.sugarPercent)
      : null;
    const oilPercent = req.body?.oilPercent
      ? Number.parseFloat(req.body.oilPercent)
      : null;

    const qualityLog = await prisma.cropQualityLog.create({
      data: {
        cropId: crop.id,
        measuredAt,
        proteinPercent,
        moisturePercent,
        sugarPercent,
        oilPercent,
        notes: req.body?.notes?.toString(),
      },
    });

    // Update crop with latest quality metrics
    await prisma.crop.update({
      where: { id: crop.id },
      data: {
        proteinPercent: proteinPercent ?? crop.proteinPercent,
        moisturePercent: moisturePercent ?? crop.moisturePercent,
        sugarPercent: sugarPercent ?? crop.sugarPercent,
        oilPercent: oilPercent ?? crop.oilPercent,
      },
    });

    // Check thresholds and notify if out of range
    const threshold = getCropThreshold(crop.cropType);
    if (threshold) {
      const alerts: string[] = [];

      if (
        proteinPercent != null &&
        threshold.idealProteinPercent &&
        (proteinPercent < threshold.idealProteinPercent.min ||
          proteinPercent > threshold.idealProteinPercent.max)
      ) {
        alerts.push(
          `Protein: ${proteinPercent.toFixed(1)}% (ideal: ${threshold.idealProteinPercent.min}-${threshold.idealProteinPercent.max}%)`,
        );
      }

      if (
        moisturePercent != null &&
        threshold.idealMoisturePercent &&
        (moisturePercent < threshold.idealMoisturePercent.min ||
          moisturePercent > threshold.idealMoisturePercent.max)
      ) {
        alerts.push(
          `Nem: ${moisturePercent.toFixed(1)}% (ideal: ${threshold.idealMoisturePercent.min}-${threshold.idealMoisturePercent.max}%)`,
        );
      }

      if (
        sugarPercent != null &&
        threshold.idealSugarPercent &&
        (sugarPercent < threshold.idealSugarPercent.min ||
          sugarPercent > threshold.idealSugarPercent.max)
      ) {
        alerts.push(
          `Şeker: ${sugarPercent.toFixed(1)}% (ideal: ${threshold.idealSugarPercent.min}-${threshold.idealSugarPercent.max}%)`,
        );
      }

      if (
        oilPercent != null &&
        threshold.idealOilPercent &&
        (oilPercent < threshold.idealOilPercent.min ||
          oilPercent > threshold.idealOilPercent.max)
      ) {
        alerts.push(
          `Yağ: ${oilPercent.toFixed(1)}% (ideal: ${threshold.idealOilPercent.min}-${threshold.idealOilPercent.max}%)`,
        );
      }

      if (alerts.length > 0) {
        await pushNotification({
          owner: crop.userId,
          title: `Kalite uyarısı: ${crop.cropType}`,
          body: `Ölçüm sonuçları ideal aralığın dışında: ${alerts.join(", ")}`,
          category: "crop",
          metadata: { cropId: crop.id, qualityLogId: qualityLog.id },
        });
      }
    }

    res.json({
      ok: true,
      qualityLog: {
        id: qualityLog.id,
        cropId: qualityLog.cropId,
        measuredAt: qualityLog.measuredAt.toISOString(),
        proteinPercent: qualityLog.proteinPercent ?? undefined,
        moisturePercent: qualityLog.moisturePercent ?? undefined,
        sugarPercent: qualityLog.sugarPercent ?? undefined,
        oilPercent: qualityLog.oilPercent ?? undefined,
        notes: qualityLog.notes ?? undefined,
      },
    });
  } catch (err) {
    next(err);
  }
}
