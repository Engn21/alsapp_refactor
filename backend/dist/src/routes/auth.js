"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_controller_1 = require("../controllers/auth.controller");
const r = (0, express_1.Router)();
r.post("/register", auth_controller_1.register);
r.post("/login", auth_controller_1.login);
exports.default = r;
