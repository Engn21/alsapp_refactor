import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import 'dotenv/config';
import { supportProgramSeeds } from "./support-seeds";

const prisma = new PrismaClient();

async function main() {
  // Seed demo user
  const email = "demo@example.com";
  const password = await bcrypt.hash("demopass", 10);
  await prisma.user.upsert({
    where: { email },
    update: {},
    create: { email, password, fullName: "Demo User" }
  });
  console.log("✓ Seeded demo user:", email);

  // Seed support programs. This is reference/catalog data (not
  // user-generated), so a full replace is safe and simpler than upserting -
  // title isn't a real unique key, so upserting by it silently duplicated
  // every row on every reseed run.
  console.log("\nSeeding support programs...");
  await prisma.supportProgram.deleteMany({});
  const { count } = await prisma.supportProgram.createMany({
    data: supportProgramSeeds,
  });
  console.log(`✓ Seeded ${count} support programs`);
}

main().finally(() => prisma.$disconnect());