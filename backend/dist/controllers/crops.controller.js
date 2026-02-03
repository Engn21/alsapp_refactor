"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listCrops = listCrops;
exports.getCropDetail = getCropDetail;
exports.createCrop = createCrop;
exports.deleteCrop = deleteCrop;
exports.recordCropSpray = recordCropSpray;
exports.recordCropHarvest = recordCropHarvest;
exports.recordCropQuality = recordCropQuality;
const prisma_1 = require("../lib/prisma");
const notifications_1 = require("../lib/notifications");
const type_thresholds_1 = require("../config/type-thresholds");
const PESTICIDE_INTERVALS = {
    fungicide: 14,
    herbicide: 21,
    insecticide: 10,
    foliar: 18,
};
const DEFAULT_SPRAY_INTERVAL = 14;
function normalize(str) {
    return str.trim().toLowerCase();
}
function toIso(date) {
    return date ? date.toISOString() : null;
}
function computeNextSprayDue(base, pesticide) {
    if (!base)
        return null;
    const interval = PESTICIDE_INTERVALS[normalize(pesticide ?? "")] ?? DEFAULT_SPRAY_INTERVAL;
    const due = new Date(base.getTime());
    due.setUTCDate(due.getUTCDate() + interval);
    return due;
}
function serializeCrop(crop) {
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
        customMetrics: crop.customMetrics ?? undefined,
        sprays: (crop.sprays ?? []).map((s) => ({
            id: s.id,
            cropId: s.cropId,
            pesticide: s.pesticide ?? undefined,
            sprayedAt: toIso(s.sprayedAt),
            createdAt: toIso(s.createdAt),
        })),
        harvests: (crop.harvests ?? []).map((h) => ({
            id: h.id,
            cropId: h.cropId,
            harvestedAt: toIso(h.harvestedAt),
            amountTon: h.amountTon,
            yieldTonPerHa: h.yieldTonPerHa ?? undefined,
            createdAt: toIso(h.createdAt),
        })),
        qualityLogs: (crop.qualityLogs ?? []).map((q) => ({
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
async function ensureCrop(ownerId, cropId) {
    const crop = await prisma_1.prisma.crop.findFirst({
        where: { id: cropId, userId: ownerId },
        include: {
            sprays: { orderBy: { sprayedAt: "desc" } },
            harvests: { orderBy: { harvestedAt: "desc" } },
            qualityLogs: { orderBy: { measuredAt: "desc" } },
        },
    });
    if (!crop) {
        const err = new Error("Crop not found");
        err.status = 404;
        throw err;
    }
    return crop;
}
async function maybeNotifySprayDue(crop) {
    if (!crop.nextSprayDueAt)
        return;
    const due = crop.nextSprayDueAt;
    const alreadyAlerted = crop.lastSprayAlertAt &&
        crop.lastSprayAlertAt.getTime() === due.getTime();
    if (alreadyAlerted)
        return;
    if (due.getTime() <= Date.now()) {
        await (0, notifications_1.pushNotification)({
            owner: crop.userId,
            title: `Spray due for ${crop.cropType}`,
            body: `It's time to apply ${crop.pesticide ?? "the planned treatment"} to ${crop.cropType}.`,
            category: "crop",
            metadata: { cropId: crop.id },
        });
        await prisma_1.prisma.crop.update({
            where: { id: crop.id },
            data: { lastSprayAlertAt: due },
        });
        crop.lastSprayAlertAt = due;
    }
}
async function listCrops(req, res) {
    const owner = req.user?.id;
    if (!owner)
        return res.json([]);
    const crops = await prisma_1.prisma.crop.findMany({
        where: { userId: owner },
        orderBy: { createdAt: "desc" },
        include: {
            sprays: { orderBy: { sprayedAt: "desc" }, take: 5 },
            harvests: { orderBy: { harvestedAt: "desc" }, take: 5 },
            qualityLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
        },
    });
    await Promise.all(crops.map(maybeNotifySprayDue));
    res.json(crops.map(serializeCrop));
}
async function getCropDetail(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
        const crop = await ensureCrop(owner, req.params.id);
        await maybeNotifySprayDue(crop);
        res.json(serializeCrop(crop));
    }
    catch (err) {
        next(err);
    }
}
async function createCrop(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
        const body = req.body ?? {};
        const cropType = (body.cropType ?? body.crop_type ?? "").toString().trim();
        if (!cropType) {
            throw Object.assign(new Error("cropType is required"), { status: 400 });
        }
        const plantingDate = new Date(body.plantingDate ?? body.planting_date);
        if (Number.isNaN(plantingDate.valueOf())) {
            throw Object.assign(new Error("plantingDate is invalid"), { status: 400 });
        }
        let harvestDate;
        if (body.harvestDate ?? body.harvest_date) {
            const parsed = new Date(body.harvestDate ?? body.harvest_date);
            if (Number.isNaN(parsed.valueOf())) {
                throw Object.assign(new Error("harvestDate is invalid"), {
                    status: 400,
                });
            }
            harvestDate = parsed;
        }
        const area = body.area ?? body.areaHectares ?? body.area_hectares;
        const areaHectares = area != null && area !== ""
            ? Number.parseFloat(area.toString())
            : undefined;
        const pesticide = (body.pesticide ?? body.pesticideType ?? "").toString().trim();
        const nextSprayDueAt = pesticide
            ? computeNextSprayDue(plantingDate, pesticide)
            : null;
        const created = await prisma_1.prisma.crop.create({
            data: {
                userId: owner,
                cropType,
                plantingDate,
                harvestDate,
                notes: body.notes?.toString(),
                areaHectares,
                pesticide: pesticide || null,
                nextSprayDueAt,
            },
            include: {
                sprays: true,
                harvests: true,
            },
        });
        await (0, notifications_1.pushNotification)({
            owner,
            title: `New crop added: ${cropType}`,
            body: `We will monitor ${cropType} for spray schedules and yields.`,
            category: "crop",
            metadata: { cropId: created.id },
        });
        res.status(201).json(serializeCrop(created));
    }
    catch (err) {
        next(err);
    }
}
async function deleteCrop(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
        await ensureCrop(owner, req.params.id);
        await prisma_1.prisma.crop.delete({ where: { id: req.params.id } });
        res.status(204).send();
    }
    catch (err) {
        next(err);
    }
}
async function recordCropSpray(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
        const crop = await ensureCrop(owner, req.params.id);
        const sprayedAt = req.body?.date ? new Date(req.body.date) : new Date();
        if (Number.isNaN(sprayedAt.valueOf())) {
            throw Object.assign(new Error("date is invalid"), { status: 400 });
        }
        const pesticide = (req.body?.pesticide ?? "").toString().trim() || crop.pesticide || null;
        const spray = await prisma_1.prisma.cropSpray.create({
            data: {
                cropId: crop.id,
                sprayedAt,
                pesticide,
            },
        });
        const nextDue = computeNextSprayDue(sprayedAt, pesticide ?? crop.pesticide);
        await prisma_1.prisma.crop.update({
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
    }
    catch (err) {
        next(err);
    }
}
async function recordCropHarvest(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
        const crop = await ensureCrop(owner, req.params.id);
        const amount = Number.parseFloat((req.body?.amount ?? req.body?.amountTon ?? req.body?.yield ?? "").toString());
        if (!Number.isFinite(amount) || amount <= 0) {
            throw Object.assign(new Error("amount must be positive"), {
                status: 400,
            });
        }
        const harvestedAt = req.body?.date ? new Date(req.body.date) : new Date();
        if (Number.isNaN(harvestedAt.valueOf())) {
            throw Object.assign(new Error("date is invalid"), { status: 400 });
        }
        const yieldPerHa = crop.areaHectares && crop.areaHectares > 0
            ? amount / crop.areaHectares
            : null;
        const harvest = await prisma_1.prisma.cropHarvest.create({
            data: {
                cropId: crop.id,
                harvestedAt,
                amountTon: amount,
                yieldTonPerHa: yieldPerHa,
            },
        });
        await prisma_1.prisma.crop.update({
            where: { id: crop.id },
            data: { harvestDate: harvestedAt },
        });
        const threshold = (0, type_thresholds_1.getCropThreshold)(crop.cropType);
        if (threshold != null &&
            yieldPerHa != null &&
            yieldPerHa < threshold.minYieldTonPerHa) {
            await (0, notifications_1.pushNotification)({
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
    }
    catch (err) {
        next(err);
    }
}
async function recordCropQuality(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
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
        const qualityLog = await prisma_1.prisma.cropQualityLog.create({
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
        await prisma_1.prisma.crop.update({
            where: { id: crop.id },
            data: {
                proteinPercent: proteinPercent ?? crop.proteinPercent,
                moisturePercent: moisturePercent ?? crop.moisturePercent,
                sugarPercent: sugarPercent ?? crop.sugarPercent,
                oilPercent: oilPercent ?? crop.oilPercent,
            },
        });
        // Check thresholds and notify if out of range
        const threshold = (0, type_thresholds_1.getCropThreshold)(crop.cropType);
        if (threshold) {
            const alerts = [];
            if (proteinPercent != null &&
                threshold.idealProteinPercent &&
                (proteinPercent < threshold.idealProteinPercent.min ||
                    proteinPercent > threshold.idealProteinPercent.max)) {
                alerts.push(`Protein: ${proteinPercent.toFixed(1)}% (ideal: ${threshold.idealProteinPercent.min}-${threshold.idealProteinPercent.max}%)`);
            }
            if (moisturePercent != null &&
                threshold.idealMoisturePercent &&
                (moisturePercent < threshold.idealMoisturePercent.min ||
                    moisturePercent > threshold.idealMoisturePercent.max)) {
                alerts.push(`Nem: ${moisturePercent.toFixed(1)}% (ideal: ${threshold.idealMoisturePercent.min}-${threshold.idealMoisturePercent.max}%)`);
            }
            if (sugarPercent != null &&
                threshold.idealSugarPercent &&
                (sugarPercent < threshold.idealSugarPercent.min ||
                    sugarPercent > threshold.idealSugarPercent.max)) {
                alerts.push(`Şeker: ${sugarPercent.toFixed(1)}% (ideal: ${threshold.idealSugarPercent.min}-${threshold.idealSugarPercent.max}%)`);
            }
            if (oilPercent != null &&
                threshold.idealOilPercent &&
                (oilPercent < threshold.idealOilPercent.min ||
                    oilPercent > threshold.idealOilPercent.max)) {
                alerts.push(`Yağ: ${oilPercent.toFixed(1)}% (ideal: ${threshold.idealOilPercent.min}-${threshold.idealOilPercent.max}%)`);
            }
            if (alerts.length > 0) {
                await (0, notifications_1.pushNotification)({
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
    }
    catch (err) {
        next(err);
    }
}
