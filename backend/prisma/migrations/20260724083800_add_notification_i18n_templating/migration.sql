-- AlterTable
ALTER TABLE "Notification" ADD COLUMN     "bodyKey" TEXT,
ADD COLUMN     "bodyParams" JSONB,
ADD COLUMN     "titleKey" TEXT,
ADD COLUMN     "titleParams" JSONB;
