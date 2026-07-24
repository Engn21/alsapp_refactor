import { Router } from "express";
import { requireAuth } from "../middleware/auth";
import {
  createLivestock,
  listLivestock,
  getLivestockDetail,
  recordMilkData,
  recordEggData,
  recordHoneyData,
  deleteLivestock,
  updateLivestock,
} from "../controllers/livestock.controller";

const router = Router();

router.use(requireAuth);
router.get("/", listLivestock);
router.post("/", createLivestock);
router.get("/:id", getLivestockDetail);
router.patch("/:id", updateLivestock);
router.post("/:id/milk", recordMilkData);
router.post("/:id/eggs", recordEggData);
router.post("/:id/honey", recordHoneyData);
router.delete("/:id", deleteLivestock);

export default router;
