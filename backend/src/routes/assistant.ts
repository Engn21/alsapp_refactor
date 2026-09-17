import { Router } from "express";
import {
  listConversations,
  createConversation,
  deleteConversation,
  sendMessage,
  getHistory,
} from "../controllers/assistant.controller";
import { assistantLimiter } from "../middleware/rateLimit";
import { requireAuth } from "../middleware/auth";

const router = Router();

router.use(requireAuth);

// Cheap DB reads/writes, no rate limit needed.
router.get("/conversations", listConversations);
router.post("/conversations", createConversation);
router.delete("/conversations/:id", deleteConversation);
router.get("/conversations/:id/messages", getHistory);

// Triggers Claude API calls, rate-limited.
router.post("/conversations/:id/message", assistantLimiter, sendMessage);

export default router;
