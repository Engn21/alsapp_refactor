"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.register = register;
exports.login = login;
const prisma_1 = require("../lib/prisma");
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const zod_1 = require("zod");
const RegisterDto = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(6),
    fullName: zod_1.z.string().optional(),
});
async function register(req, res) {
    const dto = RegisterDto.parse(req.body);
    const exists = await prisma_1.prisma.user.findUnique({ where: { email: dto.email } });
    if (exists)
        return res.status(409).json({ message: "Email already used" });
    const hash = await bcryptjs_1.default.hash(dto.password, 10);
    const user = await prisma_1.prisma.user.create({
        data: { email: dto.email, password: hash, fullName: dto.fullName },
    });
    const token = jsonwebtoken_1.default.sign({ role: user.role }, process.env.JWT_SECRET, { subject: user.id, expiresIn: "7d" });
    res.status(201).json({ token });
}
const LoginDto = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string(),
});
async function login(req, res) {
    const dto = LoginDto.parse(req.body);
    const user = await prisma_1.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user)
        return res.status(401).json({ message: "Invalid credentials" });
    const ok = await bcryptjs_1.default.compare(dto.password, user.password);
    if (!ok)
        return res.status(401).json({ message: "Invalid credentials" });
    const token = jsonwebtoken_1.default.sign({ role: user.role }, process.env.JWT_SECRET, { subject: user.id, expiresIn: "7d" });
    res.json({ token });
}
