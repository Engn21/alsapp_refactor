"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const bcryptjs_1 = __importDefault(require("bcryptjs"));
require("dotenv/config");
const prisma = new client_1.PrismaClient();
async function main() {
    const email = "demo@example.com";
    const password = await bcryptjs_1.default.hash("demopass", 10);
    await prisma.user.upsert({
        where: { email },
        update: {},
        create: { email, password, fullName: "Demo User" }
    });
    console.log("Seeded demo user:", email);
}
main().finally(() => prisma.$disconnect());
