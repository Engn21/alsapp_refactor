"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listSupports = listSupports;
exports.getSupportDetail = getSupportDetail;
exports.getSupportCategories = getSupportCategories;
exports.legacyDash = legacyDash;
const prisma_1 = require("../lib/prisma");
function toIso(date) {
    return date ? date.toISOString() : null;
}
function serializeSupport(program, lang = "tr") {
    const isEnglish = lang === "en";
    return {
        id: program.id,
        title: isEnglish && program.titleEn ? program.titleEn : program.title,
        description: isEnglish && program.descriptionEn ? program.descriptionEn : program.description,
        category: program.category,
        subcategory: program.subcategory ?? undefined,
        amount: isEnglish && program.amountEn ? program.amountEn : program.amount,
        eligibility: isEnglish && program.eligibilityEn ? program.eligibilityEn : program.eligibility,
        requiredDocs: isEnglish && program.requiredDocsEn ? program.requiredDocsEn : program.requiredDocs,
        applicationStart: toIso(program.applicationStart),
        applicationDeadline: toIso(program.applicationDeadline),
        link: program.link ?? undefined,
        status: program.status,
        targetCrops: program.targetCrops ? JSON.parse(program.targetCrops) : undefined,
        targetLivestock: program.targetLivestock ? JSON.parse(program.targetLivestock) : undefined,
        region: program.region ?? undefined,
        priority: program.priority,
        createdAt: toIso(program.createdAt),
        updatedAt: toIso(program.updatedAt),
    };
}
async function listSupports(req, res) {
    try {
        const lang = req.query.lang || "tr";
        const category = req.query.category;
        const status = req.query.status || "active";
        const cropType = req.query.cropType;
        const livestockType = req.query.livestockType;
        // Build where clause
        const where = {
            status: status,
        };
        if (category && category !== "all") {
            where.category = category;
        }
        // Filter by crop or livestock type
        if (cropType) {
            where.targetCrops = {
                contains: cropType,
            };
        }
        if (livestockType) {
            where.targetLivestock = {
                contains: livestockType,
            };
        }
        const programs = await prisma_1.prisma.supportProgram.findMany({
            where,
            orderBy: [
                { priority: "desc" },
                { applicationDeadline: "asc" },
            ],
        });
        const serialized = programs.map((p) => serializeSupport(p, lang));
        res.json(serialized);
    }
    catch (err) {
        res.status(500).json({ error: err.message || "Failed to fetch support programs" });
    }
}
async function getSupportDetail(req, res) {
    try {
        const lang = req.query.lang || "tr";
        const { id } = req.params;
        const program = await prisma_1.prisma.supportProgram.findUnique({
            where: { id },
        });
        if (!program) {
            return res.status(404).json({ error: "Support program not found" });
        }
        res.json(serializeSupport(program, lang));
    }
    catch (err) {
        res.status(500).json({ error: err.message || "Failed to fetch support program" });
    }
}
async function getSupportCategories(_req, res) {
    try {
        const categories = await prisma_1.prisma.supportProgram.groupBy({
            by: ["category"],
            _count: { category: true },
            where: { status: "active" },
        });
        const result = categories.map((cat) => ({
            category: cat.category,
            count: cat._count.category,
        }));
        res.json(result);
    }
    catch (err) {
        res.status(500).json({ error: err.message || "Failed to fetch categories" });
    }
}
// Legacy endpoint for backward compatibility
async function legacyDash(req, res) {
    return listSupports(req, res);
}
