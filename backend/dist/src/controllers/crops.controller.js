"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listCrops = listCrops;
exports.createCrop = createCrop;
const prisma_1 = require("../lib/prisma");
const zod_1 = require("zod");
const CreateCropDto = zod_1.z.object({
    cropType: zod_1.z.string().min(1),
    plantingDate: zod_1.z.string().datetime(),
    harvestDate: zod_1.z.string().datetime().optional(),
    notes: zod_1.z.string().optional(),
});
async function listCrops(req, res) {
    const crops = await prisma_1.prisma.crop.findMany({
        where: { userId: req.user.id },
        orderBy: { plantingDate: "desc" },
    });
    res.json(crops);
}
async function createCrop(req, res) {
    const dto = CreateCropDto.parse(req.body);
    const crop = await prisma_1.prisma.crop.create({
        data: {
            userId: req.user.id,
            cropType: dto.cropType,
            plantingDate: new Date(dto.plantingDate),
            harvestDate: dto.harvestDate ? new Date(dto.harvestDate) : null,
            notes: dto.notes,
        },
    });
    res.status(201).json(crop);
}
