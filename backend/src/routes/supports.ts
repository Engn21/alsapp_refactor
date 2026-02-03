import { Router } from "express";
import {
  listSupports,
  getSupportDetail,
  getSupportCategories,
} from "../controllers/supports.controller";

const router = Router();

router.get("/", listSupports);
router.get("/categories", getSupportCategories);
router.get("/:id", getSupportDetail);

export default router;
