-- AlterTable
ALTER TABLE "MinistryOffice" ADD COLUMN     "country" TEXT NOT NULL DEFAULT 'TR';

-- AlterTable
ALTER TABLE "SupportProgram" ADD COLUMN     "amountEs" TEXT,
ADD COLUMN     "country" TEXT NOT NULL DEFAULT 'TR',
ADD COLUMN     "descriptionEs" TEXT,
ADD COLUMN     "eligibilityEs" TEXT,
ADD COLUMN     "providerEs" TEXT,
ADD COLUMN     "requiredDocsEs" TEXT,
ADD COLUMN     "titleEs" TEXT;

-- CreateIndex
CREATE INDEX "MinistryOffice_country_idx" ON "MinistryOffice"("country");

-- CreateIndex
CREATE INDEX "SupportProgram_country_idx" ON "SupportProgram"("country");
