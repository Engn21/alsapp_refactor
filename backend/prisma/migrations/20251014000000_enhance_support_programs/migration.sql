-- Enhance SupportProgram table for government support tracking

-- Add new columns for multilingual support
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "titleEn" TEXT;
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "descriptionEn" TEXT;

-- Add categorization fields
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "category" TEXT NOT NULL DEFAULT 'diger';
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "subcategory" TEXT;

-- Add amount and eligibility fields
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "amount" TEXT;
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "amountEn" TEXT;
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "eligibility" TEXT;
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "eligibilityEn" TEXT;
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "requiredDocs" TEXT;
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "requiredDocsEn" TEXT;

-- Add application period tracking
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "applicationStart" TIMESTAMP(3);

-- Add status and targeting fields
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "status" TEXT NOT NULL DEFAULT 'active';
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "targetCrops" TEXT;
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "targetLivestock" TEXT;
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "region" TEXT;
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "priority" INTEGER NOT NULL DEFAULT 0;

-- Add updatedAt timestamp
ALTER TABLE "SupportProgram" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS "SupportProgram_category_idx" ON "SupportProgram"("category");
CREATE INDEX IF NOT EXISTS "SupportProgram_status_idx" ON "SupportProgram"("status");

-- Update existing records to have default category
UPDATE "SupportProgram" SET "category" = 'diger' WHERE "category" IS NULL;
