-- CreateTable
CREATE TABLE "AssistantConversation" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AssistantConversation_pkey" PRIMARY KEY ("id")
);

-- AlterTable (nullable for now - backfilled below, then made required)
ALTER TABLE "AssistantMessage" ADD COLUMN     "conversationId" TEXT;

-- Backfill: bucket each user's existing flat message history into a single
-- legacy conversation so no history is lost by this migration.
INSERT INTO "AssistantConversation" ("id", "userId", "createdAt", "updatedAt")
SELECT gen_random_uuid()::text, "userId", MIN("createdAt"), MAX("createdAt")
FROM "AssistantMessage"
GROUP BY "userId";

UPDATE "AssistantMessage" m
SET "conversationId" = c."id"
FROM "AssistantConversation" c
WHERE c."userId" = m."userId";

-- AlterTable
ALTER TABLE "AssistantMessage" ALTER COLUMN "conversationId" SET NOT NULL;

-- CreateIndex
CREATE INDEX "AssistantConversation_userId_updatedAt_idx" ON "AssistantConversation"("userId", "updatedAt");

-- CreateIndex
CREATE INDEX "AssistantMessage_conversationId_createdAt_idx" ON "AssistantMessage"("conversationId", "createdAt");

-- AddForeignKey
ALTER TABLE "AssistantConversation" ADD CONSTRAINT "AssistantConversation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AssistantMessage" ADD CONSTRAINT "AssistantMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "AssistantConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;
