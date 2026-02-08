"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.StatsController = void 0;
const stats_service_1 = require("../services/stats.service");
class StatsController {
    static async getAllStats(_req, res) {
        try {
            const stats = await stats_service_1.StatsService.getAllStats();
            // const trafficSummary = await StatsService.getTrafficSummary();
            // const activeConnections = Object.keys(stats).filter(
            //   key => key.includes('connection') && !key.includes('reset')
            // ).length;
            res.json({
                success: true,
                data: stats
            });
        }
        catch (error) {
            console.error('Error getting system stats:', error);
            res.status(500).json({
                success: false,
                error: error.message,
                stats: {},
                trafficSummary: {
                    totalUplink: 0,
                    totalDownlink: 0,
                    totalTraffic: 0,
                    uplinkGB: 0,
                    downlinkGB: 0,
                    totalGB: 0
                }
            });
        }
    }
}
exports.StatsController = StatsController;
//# sourceMappingURL=stats.controller.js.map