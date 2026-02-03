import { Router } from "express";
import { legacyDash } from "../controllers/supports.controller";

const router = Router();

router.post("/", legacyDash);

export default router;
