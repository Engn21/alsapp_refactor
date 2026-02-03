"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.register = register;
exports.login = login;
exports.me = me;
const prisma_1 = require("../lib/prisma");
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const zod_1 = require("zod");
const client_1 = require("@prisma/client");
// ---------- DTO'lar ----------
const RegisterDto = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(6),
    fullName: zod_1.z.string().optional(),
    role: zod_1.z.nativeEnum(client_1.Role).optional(), // "farmer" | "ministry"
});
const LoginDto = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string(),
});
// ---------- REGISTER ----------
async function register(req, res) {
    try {
        const dto = RegisterDto.parse(req.body);
        const exists = await prisma_1.prisma.user.findUnique({ where: { email: dto.email } });
        if (exists)
            return res.status(409).json({ message: "Email already used" });
        const hash = await bcryptjs_1.default.hash(dto.password, 10);
        const user = await prisma_1.prisma.user.create({
            data: {
                email: dto.email,
                password: hash,
                fullName: dto.fullName,
                role: dto.role ?? client_1.Role.farmer,
            },
        });
        const token = jsonwebtoken_1.default.sign({ role: user.role, email: user.email, name: user.fullName ?? null }, process.env.JWT_SECRET, { subject: user.id, expiresIn: "7d" });
        return res.status(201).json({ token });
    }
    catch (e) {
        if (e?.name === "ZodError") {
            return res.status(400).json({ message: "Invalid payload", issues: e.issues });
        }
        console.error("REGISTER error:", e);
        return res.status(500).json({ message: "Internal error" });
    }
}
// ---------- LOGIN ----------
async function login(req, res) {
    try {
        const dto = LoginDto.parse(req.body);
        const user = await prisma_1.prisma.user.findUnique({ where: { email: dto.email } });
        if (!user)
            return res.status(401).json({ message: "Invalid credentials" });
        const ok = await bcryptjs_1.default.compare(dto.password, user.password);
        if (!ok)
            return res.status(401).json({ message: "Invalid credentials" });
        const token = jsonwebtoken_1.default.sign({ role: user.role, email: user.email, name: user.fullName ?? null }, process.env.JWT_SECRET, { subject: user.id, expiresIn: "7d" });
        return res.json({ token });
    }
    catch (e) {
        if (e?.name === "ZodError") {
            return res.status(400).json({ message: "Invalid payload", issues: e.issues });
        }
        console.error("LOGIN error:", e);
        return res.status(500).json({ message: "Internal error" });
    }
}
// ---------- ME ----------
async function me(req, res) {
    if (!req.user?.id)
        return res.status(401).json({ message: "Unauthenticated" });
    const user = await prisma_1.prisma.user.findUnique({
        where: { id: req.user.id },
        select: { id: true, email: true, role: true, fullName: true },
    });
    if (!user)
        return res.status(404).json({ message: "User not found" });
    return res.json({
        id: user.id,
        email: user.email,
        role: user.role,
        fullName: user.fullName,
    });
}
