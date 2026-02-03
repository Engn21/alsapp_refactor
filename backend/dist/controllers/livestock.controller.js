"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listLivestock = listLivestock;
exports.getLivestockDetail = getLivestockDetail;
exports.createLivestock = createLivestock;
exports.deleteLivestock = deleteLivestock;
exports.recordMilkData = recordMilkData;
const prisma_1 = require("../lib/prisma");
const notifications_1 = require("../lib/notifications");
const type_thresholds_1 = require("../config/type-thresholds");
function normalize(species) {
    return species.trim().toLowerCase();
}
function toIso(date) {
    return date ? date.toISOString() : null;
}
function serializeLivestock(item) {
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
        customMetrics: item.customMetrics ?? undefined,
        milkLogs: (item.milkLogs ?? []).map((log) => ({
            id: log.id,
            livestockId: log.livestockId,
            measuredAt: toIso(log.measuredAt),
            quantityLiters: log.quantityL,
            fatPercent: log.fatPercent ?? undefined,
            createdAt: toIso(log.createdAt),
        })),
        eggLogs: (item.eggLogs ?? []).map((log) => ({
            id: log.id,
            livestockId: log.livestockId,
            measuredAt: toIso(log.measuredAt),
            eggCount: log.eggCount,
            avgWeightGram: log.avgWeightGram ?? undefined,
            createdAt: toIso(log.createdAt),
        })),
        honeyLogs: (item.honeyLogs ?? []).map((log) => ({
            id: log.id,
            livestockId: log.livestockId,
            measuredAt: toIso(log.measuredAt),
            amountKg: log.amountKg,
            qualityGrade: log.qualityGrade ?? undefined,
            createdAt: toIso(log.createdAt),
        })),
        woolLogs: (item.woolLogs ?? []).map((log) => ({
            id: log.id,
            livestockId: log.livestockId,
            shearedAt: toIso(log.shearedAt),
            amountKg: log.amountKg,
            qualityGrade: log.qualityGrade ?? undefined,
            createdAt: toIso(log.createdAt),
        })),
        weightLogs: (item.weightLogs ?? []).map((log) => ({
            id: log.id,
            livestockId: log.livestockId,
            measuredAt: toIso(log.measuredAt),
            weightKg: log.weightKg,
            notes: log.notes ?? undefined,
            createdAt: toIso(log.createdAt),
        })),
    };
}
async function ensureLivestock(ownerId, livestockId) {
    const record = await prisma_1.prisma.livestock.findFirst({
        where: { id: livestockId, userId: ownerId },
        include: {
            milkLogs: { orderBy: { measuredAt: "desc" } },
            eggLogs: { orderBy: { measuredAt: "desc" } },
            honeyLogs: { orderBy: { measuredAt: "desc" } },
            woolLogs: { orderBy: { shearedAt: "desc" } },
            weightLogs: { orderBy: { measuredAt: "desc" } },
        },
    });
    if (!record) {
        const err = new Error("Livestock not found");
        err.status = 404;
        throw err;
    }
    return record;
}
async function maybeNotifyMilk(record, log) {
    const threshold = (0, type_thresholds_1.getLivestockThreshold)(record.animalType);
    if (!threshold || !threshold.minDailyMilkL)
        return;
    const quantityLow = log.quantityL < threshold.minDailyMilkL;
    const fatLow = threshold.minMilkFatPercent != null &&
        log.fatPercent != null &&
        log.fatPercent < threshold.minMilkFatPercent;
    if (!quantityLow && !fatLow)
        return;
    const alreadyAlerted = record.lastMilkAlertAt &&
        record.lastMilkAlertAt.getTime() === log.measuredAt.getTime();
    if (alreadyAlerted)
        return;
    const reasons = [];
    if (quantityLow) {
        reasons.push(`Miktar: ${log.quantityL.toFixed(1)}L (minimum: ${threshold.minDailyMilkL}L)`);
    }
    if (fatLow) {
        reasons.push(`Yağ oranı: ${log.fatPercent?.toFixed(1)}% (minimum: ${threshold.minMilkFatPercent}%)`);
    }
    await (0, notifications_1.pushNotification)({
        owner: record.userId,
        title: `Süt üretimi uyarısı: ${record.animalType}`,
        body: `${log.measuredAt.toISOString().substring(0, 10)} tarihli ölçümde ${reasons.join(" ve ")}.`,
        category: "livestock",
        metadata: { livestockId: record.id },
    });
    await prisma_1.prisma.livestock.update({
        where: { id: record.id },
        data: { lastMilkAlertAt: log.measuredAt },
    });
    record.lastMilkAlertAt = log.measuredAt;
}
async function listLivestock(req, res) {
    const owner = req.user?.id;
    if (!owner)
        return res.json([]);
    const animals = await prisma_1.prisma.livestock.findMany({
        where: { userId: owner },
        orderBy: { createdAt: "desc" },
        include: {
            milkLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
            eggLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
            honeyLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
            woolLogs: { orderBy: { shearedAt: "desc" }, take: 5 },
            weightLogs: { orderBy: { measuredAt: "desc" }, take: 5 },
        },
    });
    res.json(animals.map(serializeLivestock));
}
async function getLivestockDetail(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
        const record = await ensureLivestock(owner, req.params.id);
        res.json(serializeLivestock(record));
    }
    catch (err) {
        next(err);
    }
}
async function createLivestock(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
        const body = req.body ?? {};
        const species = (body.species ?? body.animal_type ?? "").toString().trim();
        if (!species) {
            throw Object.assign(new Error("species is required"), { status: 400 });
        }
        let birthDate;
        if (body.birthDate ?? body.birthdate) {
            const parsed = new Date(body.birthDate ?? body.birthdate);
            if (Number.isNaN(parsed.valueOf())) {
                throw Object.assign(new Error("birthDate is invalid"), {
                    status: 400,
                });
            }
            birthDate = parsed;
        }
        const record = await prisma_1.prisma.livestock.create({
            data: {
                userId: owner,
                animalType: species,
                breed: body.breed?.toString(),
                birthDate,
                notes: body.notes?.toString(),
            },
            include: { milkLogs: true },
        });
        await (0, notifications_1.pushNotification)({
            owner,
            title: `Livestock added: ${species}`,
            body: "We will keep an eye on milk performance and alert you if needed.",
            category: "livestock",
            metadata: { livestockId: record.id },
        });
        res.status(201).json(serializeLivestock(record));
    }
    catch (err) {
        next(err);
    }
}
async function deleteLivestock(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
        await ensureLivestock(owner, req.params.id);
        await prisma_1.prisma.livestock.delete({ where: { id: req.params.id } });
        res.status(204).send();
    }
    catch (err) {
        next(err);
    }
}
async function recordMilkData(req, res, next) {
    try {
        const owner = req.user?.id;
        if (!owner)
            throw Object.assign(new Error("Unauthorized"), { status: 401 });
        const record = await ensureLivestock(owner, req.params.id);
        const quantity = Number.parseFloat((req.body?.quantity ?? req.body?.liters ?? req.body?.amount ?? "").toString());
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
        const fatPercent = fat != null && fat !== "" ? Number.parseFloat(fat.toString()) : undefined;
        const log = await prisma_1.prisma.milkLog.create({
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
    }
    catch (err) {
        next(err);
    }
}
