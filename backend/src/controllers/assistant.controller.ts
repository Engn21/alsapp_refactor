import { NextFunction, Response } from "express";
import { z } from "zod";
import { AuthedRequest } from "../middleware/auth";
import { prisma } from "../lib/prisma";
import { runAssistantTurn } from "../lib/assistant/service";
import type { ChatCompletionMessageParam } from "groq-sdk/resources/chat/completions";
import { Prisma } from "@prisma/client";

const MAX_HISTORY_MESSAGES = 20;
const HISTORY_DISPLAY_LIMIT = 100;
const TITLE_PREVIEW_LENGTH = 60;

// Messages written before the 1ms offset in sendMessage (see below) share an
// identical createdAt with their reply, so createdAt alone leaves their order
// undefined. The role enum is declared user-then-assistant, so descending role
// as a tie-break puts the reply after its question once the list is reversed.
const NEWEST_FIRST: Prisma.AssistantMessageOrderByWithRelationInput[] = [
  { createdAt: "desc" },
  { role: "desc" },
];

const SendMessageDto = z.object({
  message: z.string().trim().min(1).max(4000),
  lang: z.enum(["en", "tr", "fr"]).optional(),
  lat: z.number().optional(),
  lon: z.number().optional(),
});

// A photo diagnosis is produced entirely on the phone (own on-device model,
// nothing goes to the LLM), so this only stores the resulting exchange in the
// conversation - the farmer keeps it in their history and the assistant sees
// it as context for any follow-up question.
const SavePhotoDiagnosisDto = z.object({
  userText: z.string().trim().min(1).max(200),
  replyText: z.string().trim().min(1).max(1000),
});

function toIso(date: Date) {
  return date.toISOString();
}

// Every conversation-scoped route needs to confirm the conversation both
// exists and belongs to the caller before touching its messages.
async function requireOwnedConversation(conversationId: string, owner: string) {
  const conversation = await prisma.assistantConversation.findFirst({
    where: { id: conversationId, userId: owner },
  });
  if (!conversation) {
    throw Object.assign(new Error("Conversation not found"), { status: 404 });
  }
  return conversation;
}

export async function listConversations(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });

    const conversations = await prisma.assistantConversation.findMany({
      where: { userId: owner },
      orderBy: { updatedAt: "desc" },
      include: {
        messages: { where: { role: "user" }, orderBy: { createdAt: "asc" }, take: 1 },
      },
    });

    res.json(
      conversations.map((c) => ({
        id: c.id,
        title: c.messages[0]?.content.slice(0, TITLE_PREVIEW_LENGTH) ?? null,
        updatedAt: toIso(c.updatedAt),
      })),
    );
  } catch (err) {
    next(err);
  }
}

export async function createConversation(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });

    const conversation = await prisma.assistantConversation.create({ data: { userId: owner } });

    res.status(201).json({ id: conversation.id, title: null, updatedAt: toIso(conversation.updatedAt) });
  } catch (err) {
    next(err);
  }
}

export async function deleteConversation(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });

    await requireOwnedConversation(req.params.id, owner);
    await prisma.assistantConversation.delete({ where: { id: req.params.id } });

    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

export async function sendMessage(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });

    const conversationId = req.params.id;
    await requireOwnedConversation(conversationId, owner);

    const dto = SendMessageDto.parse(req.body);
    const lang = dto.lang ?? "tr";

    const historyRows = await prisma.assistantMessage.findMany({
      where: { conversationId },
      orderBy: NEWEST_FIRST,
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

    const now = Date.now();
    await prisma.$transaction([
      // Explicit, distinct createdAt values: within a single transaction
      // Postgres's CURRENT_TIMESTAMP (Prisma's @default(now())) is frozen
      // at transaction start, so both rows would otherwise get an
      // identical timestamp and sort ambiguously - sometimes rendering
      // the reply above the question it answers.
      prisma.assistantMessage.create({
        data: {
          userId: owner,
          conversationId,
          role: "user",
          content: dto.message,
          createdAt: new Date(now),
        },
      }),
      prisma.assistantMessage.create({
        data: {
          userId: owner,
          conversationId,
          role: "assistant",
          content: turn.replyText,
          toolCalls: turn.toolCallAudit.length
            ? (turn.toolCallAudit as unknown as Prisma.InputJsonValue)
            : undefined,
          createdAt: new Date(now + 1),
        },
      }),
      prisma.assistantConversation.update({
        where: { id: conversationId },
        data: { updatedAt: new Date() },
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

export async function savePhotoDiagnosis(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const owner = req.user?.id;
    if (!owner) throw Object.assign(new Error("Unauthorized"), { status: 401 });

    const conversationId = req.params.id;
    await requireOwnedConversation(conversationId, owner);

    const dto = SavePhotoDiagnosisDto.parse(req.body);

    // Same explicit 1ms offset as sendMessage, so the reply sorts after the photo.
    const now = Date.now();
    await prisma.$transaction([
      prisma.assistantMessage.create({
        data: { userId: owner, conversationId, role: "user", content: dto.userText, createdAt: new Date(now) },
      }),
      prisma.assistantMessage.create({
        data: { userId: owner, conversationId, role: "assistant", content: dto.replyText, createdAt: new Date(now + 1) },
      }),
      prisma.assistantConversation.update({
        where: { id: conversationId },
        data: { updatedAt: new Date() },
      }),
    ]);

    res.status(204).send();
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

    const conversationId = req.params.id;
    await requireOwnedConversation(conversationId, owner);

    const rows = await prisma.assistantMessage.findMany({
      where: { conversationId },
      orderBy: NEWEST_FIRST,
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
