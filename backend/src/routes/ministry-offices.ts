import { Router } from "express";
import { listMinistryOffices } from "../controllers/ministry-offices.controller";
import { requireAuth } from "../middleware/auth";

const router = Router();

router.use(requireAuth);

// /api/ministry-offices
router.get("/", listMinistryOffices);

export default router;
