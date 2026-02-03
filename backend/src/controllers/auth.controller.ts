import { prisma } from "../lib/prisma";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { Request, Response } from "express";
import { AuthedRequest } from "../middleware/auth";
import { Role } from "@prisma/client";

// ---------- DTO'lar ----------
const RegisterDto = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  fullName: z.string().optional(),
  role: z.nativeEnum(Role).optional(), // "farmer" | "ministry"
});

const LoginDto = z.object({
  email: z.string().email(),
  password: z.string(),
});

// ---------- REGISTER ----------
export async function register(req: Request, res: Response) {
  try {
    const dto = RegisterDto.parse(req.body);

    const exists = await prisma.user.findUnique({ where: { email: dto.email } });
    if (exists) return res.status(409).json({ message: "Email already used" });

    const hash = await bcrypt.hash(dto.password, 10);

    const user = await prisma.user.create({
      data: {
        email: dto.email,
        password: hash,
        fullName: dto.fullName,
        role: dto.role ?? Role.farmer,
      },
    });

    const token = jwt.sign(
      { role: user.role, email: user.email, name: user.fullName ?? null },
      process.env.JWT_SECRET!,
      { subject: user.id, expiresIn: "7d" }
    );

    return res.status(201).json({ token });
  } catch (e: any) {
    if (e?.name === "ZodError") {
      return res.status(400).json({ message: "Invalid payload", issues: e.issues });
    }
    console.error("REGISTER error:", e);
    return res.status(500).json({ message: "Internal error" });
  }
}

// ---------- LOGIN ----------
export async function login(req: Request, res: Response) {
  try {
    const dto = LoginDto.parse(req.body);

    const user = await prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) return res.status(401).json({ message: "Invalid credentials" });

    const ok = await bcrypt.compare(dto.password, user.password);
    if (!ok) return res.status(401).json({ message: "Invalid credentials" });

    const token = jwt.sign(
      { role: user.role, email: user.email, name: user.fullName ?? null },
      process.env.JWT_SECRET!,
      { subject: user.id, expiresIn: "7d" }
    );

    return res.json({ token });
  } catch (e: any) {
    if (e?.name === "ZodError") {
      return res.status(400).json({ message: "Invalid payload", issues: e.issues });
    }
    console.error("LOGIN error:", e);
    return res.status(500).json({ message: "Internal error" });
  }
}

// ---------- ME ----------
export async function me(req: AuthedRequest, res: Response) {
  if (!req.user?.id) return res.status(401).json({ message: "Unauthenticated" });

  const user = await prisma.user.findUnique({
    where: { id: req.user.id },
    select: { id: true, email: true, role: true, fullName: true },
  });
  if (!user) return res.status(404).json({ message: "User not found" });

  return res.json({
    id: user.id,
    email: user.email,
    role: user.role,
    fullName: user.fullName,
  });
}
