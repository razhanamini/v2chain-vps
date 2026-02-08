"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ConfigController = void 0;
const xray_service_1 = require("../services/xray.service");
class ConfigController {
    static async getConfig(_req, res) {
        try {
            console.log('Getting Xray config...');
            const config = await xray_service_1.XrayService.getConfig();
            res.json({
                success: true,
                config
            });
        }
        catch (error) {
            console.error('Error reading config:', error);
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    }
    static async updateConfig(req, res) {
        try {
            const config = req.body.config || req.body;
            console.log('Updating Xray config...');
            const backupPath = await xray_service_1.XrayService.updateConfig(config);
            res.json({
                success: true,
                message: 'Config updated successfully',
                backup: backupPath
            });
        }
        catch (error) {
            console.error('Error updating config:', error);
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    }
    static async restartService(_req, res) {
        try {
            console.log('Restarting Xray service...');
            const result = await xray_service_1.XrayService.restartService();
            res.json({
                success: result.success,
                message: result.success ?
                    'Service restarted successfully' :
                    'Service may not be running',
                output: result.output
            });
        }
        catch (error) {
            console.error('Error restarting service:', error);
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    }
}
exports.ConfigController = ConfigController;
//# sourceMappingURL=config.controller.js.map