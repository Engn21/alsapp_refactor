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

  // Seed support programs
  console.log("\nSeeding support programs...");
  let count = 0;
  for (const program of supportProgramSeeds) {
    await prisma.supportProgram.upsert({
      where: { id: program.title }, // Use title as unique identifier
      update: program,
      create: program,
    }).catch(() => {
      // If upsert by title fails, just create
      return prisma.supportProgram.create({ data: program });
    });
    count++;
  }
  console.log(`✓ Seeded ${count} support programs`);
}

main().finally(() => prisma.$disconnect());