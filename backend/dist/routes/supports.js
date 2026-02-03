"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const supports_controller_1 = require("../controllers/supports.controller");
const router = (0, express_1.Router)();
router.get("/", supports_controller_1.listSupports);
router.get("/categories", supports_controller_1.getSupportCategories);
router.get("/:id", supports_controller_1.getSupportDetail);
exports.default = router;
