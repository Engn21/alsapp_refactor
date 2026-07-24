-- CreateTable
CREATE TABLE "MinistryOffice" (
    "id" TEXT NOT NULL,
    "province" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lon" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MinistryOffice_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MinistryOffice_province_idx" ON "MinistryOffice"("province");
