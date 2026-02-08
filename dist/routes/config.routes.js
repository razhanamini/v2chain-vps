"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const config_controller_1 = require("../controller/config.controller");
const router = (0, express_1.Router)();
router.get('/config', config_controller_1.ConfigController.getConfig);
router.put('/config', config_controller_1.ConfigController.updateConfig);
router.post('/restart', config_controller_1.ConfigController.restartService);
exports.default = router;
//# sourceMappingURL=config.routes.js.map