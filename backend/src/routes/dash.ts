import { Router } from "express";
import { requireAuth } from "../middleware/auth";
import { legacyDash } from "../controllers/supports.controller";

const router = Router();

router.use(requireAuth);
router.post("/", legacyDash);

export default router;
