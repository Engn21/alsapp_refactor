"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const supports_controller_1 = require("../controllers/supports.controller");
const router = (0, express_1.Router)();
router.post("/", supports_controller_1.legacyDash);
exports.default = router;
