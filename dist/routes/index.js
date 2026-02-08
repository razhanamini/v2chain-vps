"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const config_routes_1 = __importDefault(require("./config.routes"));
const stats_routes_1 = __importDefault(require("./stats.routes"));
const auth_1 = require("../middleware/auth");
const router = (0, express_1.Router)();
router.use('/api/xray', auth_1.staticTokenAuth);
router.use('/api/xray', config_routes_1.default);
router.use('/api/xray', stats_routes_1.default);
exports.default = router;
//# sourceMappingURL=index.js.map