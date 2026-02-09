import { SudoUtils } from '../utils/sudo.utils';
// import { XrayUtils } from '../utils/xray.utils';
import { XrayConfig, XrayStatus } from '../types';

export class XrayService {
  private static readonly XRAY_CONFIG_PATH = process.env.XRAY_CONFIG_PATH || "/etc/xray/config.json";
  
  static async getConfig(): Promise<XrayConfig> {
    const configData = await SudoUtils.readFileWithSudo(this.XRAY_CONFIG_PATH);
    return JSON.parse(configData);
  }
  
  static async updateConfig(config: XrayConfig): Promise<string> {
    const backupPath = `${this.XRAY_CONFIG_PATH}.backup.${Date.now()}`;
    await SudoUtils.executeSudoCommand(`cp ${this.XRAY_CONFIG_PATH} ${backupPath}`);
    
    await SudoUtils.writeFileWithSudo(
      this.XRAY_CONFIG_PATH, 
      JSON.stringify(config, null, 2)
    );
    
    return backupPath;
  }
  
  static async restartService(): Promise<{ success: boolean; output: string }> {
    const { stdout } = await SudoUtils.executeSudoCommand('systemctl restart xray');
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const { stdout: status } = await SudoUtils.executeSudoCommand('systemctl is-active xray');
    const isRunning = status.trim() === 'active';
    
    return {
      success: isRunning,
      output: stdout
    };
  }
  
  static async getVersion(): Promise<string> {
    try {
      const { stdout } = await SudoUtils.executeSudoCommand('xray --version');
      const match = stdout.match(/Xray (\d+\.\d+\.\d+)/);
      return match ? match[1] : 'Unknown';
    } catch {
      try {
        const { stdout } = await SudoUtils.executeSudoCommand('/usr/local/bin/xray --version');
        const match = stdout.match(/(\d+\.\d+\.\d+)/);
        return match ? match[1] : 'Unknown';
      } catch {
        return 'Unknown';
      }
    }
  }
  
  static async getServiceStatus(): Promise<XrayStatus> {
    let systemStatus = "Unknown";
    try {
      const { stdout } = await SudoUtils.executeSudoCommand('systemctl is-active xray');
      systemStatus = stdout.trim();
    } catch {
      systemStatus = "inactive";
    }
    
    let uptime = "Unknown";
    try {
      const { stdout: uptimeOut } = await SudoUtils.executeSudoCommand(
        'ps -o etime= -p $(pgrep xray)'
      );
      uptime = uptimeOut.trim() || "Unknown";
    } catch {
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