"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.StatsService = void 0;
// import { XrayService } from './xray.service';
// import { XrayUtils } from '../utils/xray.utils';
// import { UserStats, TrafficSummary } from '../types';
const xtls_sdk_1 = require("@remnawave/xtls-sdk");
// interface GetUserStatsResponseModel {
//   user: IUserStat | null;
// }
// interface GetSysStatsResponseModel extends ISysStats {}
class StatsService {
    static async getAllStats() {
        const api = await this.getClient();
        const response = await api.stats.getAllUsersStats();
        console.log('SDK getAllUsersStats response:', JSON.stringify(response, null, 2));
        return JSON.stringify(response, null, 2);
    }
    //   // Initialize connection to Xray gRPC API
    static async getClient() {
        if (!this.apiClient) {
            try {
                this.apiClient = new xtls_sdk_1.XtlsApi({
                    connectionUrl: `${this.XRAY_API_ADDRESS}:${this.XRAY_API_PORT}`
                });
                console.log('✅ Connected to Xray gRPC API');
            }
            catch (error) {
                console.error('Failed to initialize Xray client:', error.message);
                throw error;
            }
        }
        return this.apiClient;
    }
}
exports.StatsService = StatsService;
StatsService.apiClient = null;
StatsService.XRAY_API_ADDRESS = '127.0.0.1';
StatsService.XRAY_API_PORT = 10085;
//# sourceMappingURL=stats.service.js.map