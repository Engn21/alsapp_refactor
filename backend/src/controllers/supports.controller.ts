import { Request, Response } from "express";
import { prisma } from "../lib/prisma";

function toIso(date: Date | null | undefined) {
  return date ? date.toISOString() : null;
}

function serializeSupport(program: any, lang: string = "tr") {
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

export async function listSupports(req: Request, res: Response) {
  try {
    const lang = (req.query.lang as string) || "tr";
    const category = req.query.category as string | undefined;
    const status = (req.query.status as string) || "active";
    const cropType = req.query.cropType as string | undefined;
    const livestockType = req.query.livestockType as string | undefined;

    // Build where clause
    const where: any = {
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

    const programs = await prisma.supportProgram.findMany({
      where,
      orderBy: [
        { priority: "desc" },
        { applicationDeadline: "asc" },
      ],
    });

    const serialized = programs.map((p) => serializeSupport(p, lang));
    res.json(serialized);
  } catch (err: any) {
    res.status(500).json({ error: err.message || "Failed to fetch support programs" });
  }
}

export async function getSupportDetail(req: Request, res: Response) {
  try {
    const lang = (req.query.lang as string) || "tr";
    const { id } = req.params;

    const program = await prisma.supportProgram.findUnique({
      where: { id },
    });

    if (!program) {
      return res.status(404).json({ error: "Support program not found" });
    }

    res.json(serializeSupport(program, lang));
  } catch (err: any) {
    res.status(500).json({ error: err.message || "Failed to fetch support program" });
  }
}

export async function getSupportCategories(_req: Request, res: Response) {
  try {
    const categories = await prisma.supportProgram.groupBy({
      by: ["category"],
      _count: { category: true },
      where: { status: "active" },
    });

    const result = categories.map((cat) => ({
      category: cat.category,
      count: cat._count.category,
    }));

    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message || "Failed to fetch categories" });
  }
}

// Legacy endpoint for backward compatibility
export async function legacyDash(req: Request, res: Response) {
  return listSupports(req, res);
}
