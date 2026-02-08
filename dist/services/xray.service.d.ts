import { XrayConfig, XrayStatus } from '../types';
export declare class XrayService {
    private static readonly XRAY_CONFIG_PATH;
    static getConfig(): Promise<XrayConfig>;
    static updateConfig(config: XrayConfig): Promise<string>;
    static restartService(): Promise<{
        success: boolean;
        output: string;
    }>;
    static getVersion(): Promise<string>;
    static getServiceStatus(): Promise<XrayStatus>;
}
//# sourceMappingURL=xray.service.d.ts.map