import { Router } from "express";
import { requireAuth } from "../middleware/auth";
import {
  createCrop,
  listCrops,
  getCropDetail,
  recordCropHarvest,
  recordCropSpray,
  recordCropQuality,
  deleteCrop,
  updateCrop,
} from "../controllers/crops.controller";

const r = Router();
r.use(requireAuth);
r.get("/", listCrops);
r.post("/", createCrop);
r.get("/:id", getCropDetail);
r.patch("/:id", updateCrop);
r.post("/:id/spray", recordCropSpray);
r.post("/:id/harvest", recordCropHarvest);
r.post("/:id/quality", recordCropQuality);
r.delete("/:id", deleteCrop);

export default r;
