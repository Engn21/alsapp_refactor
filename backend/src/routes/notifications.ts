import { Router } from "express";
import { listAll, markRead } from "../controllers/notifications.controller";
import { requireAuth } from "../middleware/auth";

const router = Router();

router.use(requireAuth);
router.get("/", listAll);
router.post("/:id/read", markRead);

export default router;
