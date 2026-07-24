import { Response } from "express";
import { AuthedRequest } from "../middleware/auth";
import { prisma } from "../lib/prisma";
import { pushNotification } from "../lib/notifications";

const REMINDER_WINDOW_DAYS = 14;

function toIso(date: Date | null | undefined) {
  return date ? date.toISOString() : null;
}

// Falls back to Turkish when a translation is missing (e.g. French
// content isn't written yet - only tr/en have real translations today).
function localized(program: any, lang: string, field: string) {
  if (lang === "en" && program[`${field}En`]) return program[`${field}En`];
  if (lang === "fr" && program[`${field}Fr`]) return program[`${field}Fr`];
  return program[field];
}

// The stored `status` is set once and never re-checked, so a program past
// its own applicationDeadline would otherwise still claim to be "active".
function effectiveStatus(program: any): string {
  if (
    program.status === "active" &&
    program.applicationDeadline &&
    new Date(program.applicationDeadline).getTime() < Date.now()
  ) {
    return "expired";
  }
  return program.status;
}

interface FarmProfile {
  cropTypes: Set<string>;
  livestockTypes: Set<string>;
}

async function getFarmProfile(owner: string): Promise<FarmProfile> {
  const [crops, livestock] = await Promise.all([
    prisma.crop.findMany({
      where: { userId: owner },
      select: { cropType: true },
      distinct: ["cropType"],
    }),
    prisma.livestock.findMany({
      where: { userId: owner },
      select: { animalType: true },
      distinct: ["animalType"],
    }),
  ]);
  return {
    cropTypes: new Set(crops.map((c) => c.cropType.toLowerCase())),
    livestockTypes: new Set(livestock.map((l) => l.animalType.toLowerCase())),
  };
}

// A program with neither targetCrops nor targetLivestock is broadly
// applicable (credit, rural development, young farmer grants, etc.) and
// counts as relevant to everyone. Otherwise it matches only if the farmer
// actually grows/raises something the program targets.
function matchesFarm(program: any, profile: FarmProfile): boolean {
  const targetCrops: string[] = program.targetCrops
    ? JSON.parse(program.targetCrops)
    : [];
  const targetLivestock: string[] = program.targetLivestock
    ? JSON.parse(program.targetLivestock)
    : [];

  if (targetCrops.length === 0 && targetLivestock.length === 0) return true;

  const cropMatch = targetCrops.some((c) =>
    profile.cropTypes.has(c.toLowerCase()),
  );
  const livestockMatch = targetLivestock.some((l) =>
    profile.livestockTypes.has(l.toLowerCase()),
  );
  return cropMatch || livestockMatch;
}

function serializeSupport(
  program: any,
  lang: string = "tr",
  isMatch: boolean = false,
) {
  return {
    id: program.id,
    // SupportService._parseSupports() on the frontend filters on this -
    // without it, every real API result gets silently dropped and the
    // screen falls back to the local Turkish-only demo data instead.
    type: "support",
    title: localized(program, lang, "title"),
    description: localized(program, lang, "description"),
    category: program.category,
    subcategory: program.subcategory ?? undefined,
    amount: localized(program, lang, "amount"),
    eligibility: localized(program, lang, "eligibility"),
    requiredDocs: localized(program, lang, "requiredDocs"),
    applicationStart: toIso(program.applicationStart),
    applicationDeadline: toIso(program.applicationDeadline),
    link: program.link ?? undefined,
    provider: localized(program, lang, "provider"),
    officialGazetteUrl: program.officialGazetteUrl ?? undefined,
    institutionUrl: program.link ?? undefined,
    status: effectiveStatus(program),
    targetCrops: program.targetCrops ? JSON.parse(program.targetCrops) : undefined,
    targetLivestock: program.targetLivestock ? JSON.parse(program.targetLivestock) : undefined,
    region: program.region ?? undefined,
    priority: program.priority,
    matchesFarm: isMatch,
    createdAt: toIso(program.createdAt),
    updatedAt: toIso(program.updatedAt),
  };
}

// Notifies once per program when its deadline is within the reminder
// window - dedups by checking for a prior notification carrying the same
// supportProgramId in its metadata, so re-fetching the list repeatedly
// doesn't spam the user.
async function maybeNotifyUpcomingDeadlines(
  owner: string,
  matchedPrograms: any[],
) {
  const now = Date.now();
  const windowMs = REMINDER_WINDOW_DAYS * 24 * 60 * 60 * 1000;

  const soonDue = matchedPrograms.filter((p) => {
    if (!p.applicationDeadline) return false;
    const deadlineMs = new Date(p.applicationDeadline).getTime();
    return deadlineMs > now && deadlineMs - now <= windowMs;
  });

  for (const program of soonDue) {
    const alreadyNotified = await prisma.notification.findFirst({
      where: {
        userId: owner,
        metadata: { path: ["supportProgramId"], equals: program.id },
      },
    });
    if (alreadyNotified) continue;

    const daysLeft = Math.ceil(
      (new Date(program.applicationDeadline).getTime() - now) / (24 * 60 * 60 * 1000),
    );
    const deadlineDate = new Date(program.applicationDeadline)
      .toISOString()
      .substring(0, 10);
    await pushNotification({
      owner,
      title: `Destek süresi yaklaşıyor: ${program.title}`,
      body: `Başvuru için ${daysLeft} gün kaldı (son tarih: ${deadlineDate}).`,
      titleKey: "notif.supportDeadline.title",
      // program.title has no localized variant stored on the notification
      // itself (only the SupportProgram row does) - the English/French
      // fallback strings above use the Turkish title, matching prior
      // behavior; the client can look up the program by supportProgramId
      // in metadata for a fully localized title if needed later.
      titleParams: { title: program.title },
      bodyKey: "notif.supportDeadline.body",
      bodyParams: { days: daysLeft, deadline: deadlineDate },
      category: "support",
      metadata: { supportProgramId: program.id },
    });
  }
}

export async function listSupports(req: AuthedRequest, res: Response) {
  try {
    const owner = req.user?.id;
    const lang = (req.query.lang as string) || "tr";
    const category = req.query.category as string | undefined;
    const status = (req.query.status as string) || "active";
    const cropType = req.query.cropType as string | undefined;
    const livestockType = req.query.livestockType as string | undefined;

    // Build where clause
    const where: any = {
      status: status,
    };

    // A program stored as "active" whose deadline has already passed
    // shouldn't be returned as an active result.
    if (status === "active") {
      where.OR = [
        { applicationDeadline: null },
        { applicationDeadline: { gte: new Date() } },
      ];
    }

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

    const profile = owner
      ? await getFarmProfile(owner)
      : { cropTypes: new Set<string>(), livestockTypes: new Set<string>() };

    // Farm-relevant programs first (stable sort keeps the priority/deadline
    // ordering already applied within each group).
    const withMatch = programs.map((p) => ({
      program: p,
      isMatch: matchesFarm(p, profile),
    }));
    withMatch.sort((a, b) => Number(b.isMatch) - Number(a.isMatch));

    if (owner) {
      const matched = withMatch.filter((x) => x.isMatch).map((x) => x.program);
      await maybeNotifyUpcomingDeadlines(owner, matched);
    }

    const serialized = withMatch.map((x) =>
      serializeSupport(x.program, lang, x.isMatch),
    );
    res.json(serialized);
  } catch (err: any) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch support programs" });
  }
}

export async function getSupportDetail(req: AuthedRequest, res: Response) {
  try {
    const owner = req.user?.id;
    const lang = (req.query.lang as string) || "tr";
    const { id } = req.params;

    const program = await prisma.supportProgram.findUnique({
      where: { id },
    });

    if (!program) {
      return res.status(404).json({ error: "Support program not found" });
    }

    const profile = owner
      ? await getFarmProfile(owner)
      : { cropTypes: new Set<string>(), livestockTypes: new Set<string>() };

    res.json(serializeSupport(program, lang, matchesFarm(program, profile)));
  } catch (err: any) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch support program" });
  }
}

export async function getSupportCategories(_req: AuthedRequest, res: Response) {
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
    console.error(err);
    res.status(500).json({ error: "Failed to fetch categories" });
  }
}

// Legacy endpoint for backward compatibility
export async function legacyDash(req: AuthedRequest, res: Response) {
  return listSupports(req, res);
}
