import { Router } from "express";
import { requireAuth } from "../middleware/auth";
import {
  listSupports,
  getSupportDetail,
  getSupportCategories,
} from "../controllers/supports.controller";

const router = Router();

router.use(requireAuth);
router.get("/", listSupports);
router.get("/categories", getSupportCategories);
router.get("/:id", getSupportDetail);

export default router;
