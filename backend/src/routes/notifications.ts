import { Router } from "express";
import { listAll, markRead, registerDevice } from "../controllers/notifications.controller";
import { requireAuth } from "../middleware/auth";

const router = Router();

router.use(requireAuth);
router.get("/", listAll);
router.post("/:id/read", markRead);
router.post("/register-device", registerDevice);

export default router;
