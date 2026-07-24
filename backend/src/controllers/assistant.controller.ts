import { NextFunction, Response } from "express";
import { z } from "zod";
import { AuthedRequest } from "../middleware/auth";
import { prisma } from "../lib/prisma";
import { runAssistantTurn } from "../lib/assistant/service";
import type { ChatCompletionMessageParam } from "groq-sdk/resources/chat/completions";
import { Prisma } from "@prisma/client";

const MAX_HISTORY_MESSAGES = 20;
const HISTORY_DISPLAY_LIMIT = 100;

const SendMessageDto = z.object({
  message: z.string().trim().min(1).max(4000),
  lang: z.enum(["en", "tr", "fr"]).optional(),
  lat: z.number().optional(),
  lon: z.number().optional(),
});

function toIso(date: Date) {
  return date.toISOString();
}

export async function sendMessage(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });

    const dto = SendMessageDto.parse(req.body);
    const lang = dto.lang ?? "tr";

    const historyRows = await prisma.assistantMessage.findMany({
      where: { userId: owner },
      orderBy: { createdAt: "desc" },
      take: MAX_HISTORY_MESSAGES,
    });
    const history: ChatCompletionMessageParam[] = historyRows
      .reverse()
      .map((row) => ({ role: row.role, content: row.content }));

    let turn;
    try {
      turn = await runAssistantTurn(
        { userId: owner, lang, lat: dto.lat, lon: dto.lon },
        history,
        dto.message,
      );
    } catch (e: any) {
      // Don't leak raw Groq SDK/network error details to the client,
      // but keep them in the server log for debugging.
      console.error("[assistant] runAssistantTurn failed:", e);
      throw Object.assign(new Error("Assistant is temporarily unavailable"), {
        status: e?.status ?? 500,
      });
    }

    await prisma.$transaction([
      prisma.assistantMessage.create({
        data: { userId: owner, role: "user", content: dto.message },
      }),
      prisma.assistantMessage.create({
        data: {
          userId: owner,
          role: "assistant",
          content: turn.replyText,
          toolCalls: turn.toolCallAudit.length
            ? (turn.toolCallAudit as unknown as Prisma.InputJsonValue)
            : undefined,
        },
      }),
    ]);

    res.json({ reply: turn.replyText });
  } catch (err: any) {
    if (err?.name === "ZodError") {
      return res.status(400).json({ message: "Invalid payload", issues: err.issues });
    }
    next(err);
  }
}

export async function getHistory(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });

    const rows = await prisma.assistantMessage.findMany({
      where: { userId: owner },
      orderBy: { createdAt: "desc" },
      take: HISTORY_DISPLAY_LIMIT,
    });

    res.json(
      rows.reverse().map((row) => ({
        id: row.id,
        role: row.role,
        content: row.content,
        createdAt: toIso(row.createdAt),
      })),
    );
  } catch (err) {
    next(err);
  }
}
