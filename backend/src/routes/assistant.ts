import { Router } from "express";
import { sendMessage, getHistory } from "../controllers/assistant.controller";
import { assistantLimiter } from "../middleware/rateLimit";
import { requireAuth } from "../middleware/auth";

const router = Router();

router.use(requireAuth);

// /api/assistant/messages - cheap DB read, no rate limit needed
router.get("/messages", getHistory);

// /api/assistant/message - triggers Claude API calls, rate-limited
router.post("/message", assistantLimiter, sendMessage);

export default router;
