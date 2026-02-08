"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.XrayService = void 0;
const sudo_utils_1 = require("../utils/sudo.utils");
class XrayService {
    static async getConfig() {
        const configData = await sudo_utils_1.SudoUtils.readFileWithSudo(this.XRAY_CONFIG_PATH);
        return JSON.parse(configData);
    }
    static async updateConfig(config) {
        const backupPath = `${this.XRAY_CONFIG_PATH}.backup.${Date.now()}`;
        await sudo_utils_1.SudoUtils.executeSudoCommand(`cp ${this.XRAY_CONFIG_PATH} ${backupPath}`);
        await sudo_utils_1.SudoUtils.writeFileWithSudo(this.XRAY_CONFIG_PATH, JSON.stringify(config, null, 2));
        return backupPath;
    }
    static async restartService() {
        const { stdout } = await sudo_utils_1.SudoUtils.executeSudoCommand('systemctl restart xray');
        await new Promise(resolve => setTimeout(resolve, 2000));
        const { stdout: status } = await sudo_utils_1.SudoUtils.executeSudoCommand('systemctl is-active xray');
        const isRunning = status.trim() === 'active';
        return {
            success: isRunning,
            output: stdout
        };
    }
    static async getVersion() {
        try {
            const { stdout } = await sudo_utils_1.SudoUtils.executeSudoCommand('xray --version');
            const match = stdout.match(/Xray (\d+\.\d+\.\d+)/);
            return match ? match[1] : 'Unknown';
        }
        catch {
            try {
                const { stdout } = await sudo_utils_1.SudoUtils.executeSudoCommand('/usr/local/bin/xray --version');
                const match = stdout.match(/(\d+\.\d+\.\d+)/);
                return match ? match[1] : 'Unknown';
            }
            catch {
                return 'Unknown';
            }
        }
    }
    static async getServiceStatus() {
        let systemStatus = "Unknown";
        try {
            const { stdout } = await sudo_utils_1.SudoUtils.executeSudoCommand('systemctl is-active xray');
            systemStatus = stdout.trim();
        }
        catch {
            systemStatus = "inactive";
        }
        let uptime = "Unknown";
        try {
            const { stdout: uptimeOut } = await sudo_utils_1.SudoUtils.executeSudoCommand('ps -o etime= -p $(pgrep xray)');
            uptime = uptimeOut.trim() || "Unknown";
        }
        catch {
            uptime = "Unknown";
        }
        const version = await this.getVersion();
        const isRunning = systemStatus === 'active';
        return {
            isRunning,
            uptime,
            version,
            activeConnections: 0,
            totalUsers: 0,
            trafficSummary: {
                totalUplink: 0,
                totalDownlink: 0,
                totalTraffic: 0,
                uplinkGB: 0,
                downlinkGB: 0,
                totalGB: 0
            },
            systemStatus,
            lastUpdated: new Date().toISOString()
        };
    }
}
exports.XrayService = XrayService;
XrayService.XRAY_CONFIG_PATH = '/usr/local/etc/xray/config.json';
//# sourceMappingURL=xray.service.js.map