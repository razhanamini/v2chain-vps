export interface XrayUser {
    id: string;
    uuid: string;
    email: string;
    bandwidthLimit: number;
    expiryDate: string | null;
    dataUsed: number;
    dataUsedBytes: number;
    uplink: number;
    downlink: number;
    enabled: boolean;
    createdAt: string;
    protocols: string[];
    flow: string;
    limitIp: number;
    subscriptionUrl: string;
    stats?: UserStats;
}
export interface UserStats {
    uplink: number;
    downlink: number;
    total: number;
}
export interface TrafficSummary {
    totalUplink: number;
    totalDownlink: number;
    totalTraffic: number;
    uplinkGB: number;
    downlinkGB: number;
    totalGB: number;
}
export interface XrayStatus {
    isRunning: boolean;
    uptime: string;
    version: string;
    activeConnections: number;
    totalUsers: number;
    trafficSummary: TrafficSummary;
    systemStatus: string;
    lastUpdated: string;
}
export interface CommandResult {
    success: boolean;
    stdout: string;
    stderr: string;
    code?: number;
    error?: string;
}
export interface CreateUserRequest {
    email: string;
    bandwidthLimit: number;
    expiryDays?: number;
    flow?: string;
    limitIp?: number;
}
export interface UpdateUserRequest {
    email?: string;
    bandwidthLimit?: number;
    expiryDays?: number;
}
export interface XrayClientConfig {
    address: string;
    port: number;
}
export interface XrayUserStats {
    uplink: number;
    downlink: number;
    total: number;
    email: string;
}
export interface XraySystemStats {
    totalUplink: number;
    totalDownlink: number;
    connections: number;
}
export interface XrayConfig {
    log?: {
        loglevel: 'debug' | 'info' | 'warning' | 'error' | 'none';
        access?: string;
        error?: string;
    };
    api?: {
        tag: string;
        services: string[];
        listen?: string;
    };
    stats?: {
        enabled?: boolean;
        statsFile?: string;
    };
    policy?: {
        levels: {
            [key: string]: {
                handshake?: number;
                connIdle?: number;
                downlinkOnly?: number;
                uplinkOnly?: number;
                bufferSize?: number;
                statsUserUplink?: boolean;
                statsUserDownlink?: boolean;
            };
        };
        system?: {
            statsInboundUplink?: boolean;
            statsInboundDownlink?: boolean;
            statsOutboundUplink?: boolean;
            statsOutboundDownlink?: boolean;
        };
    };
    inbounds: Array<{
        port: number;
        protocol: string;
        settings: {
            clients?: Array<{
                id: string;
                email: string;
                flow?: string;
                limitIp?: number;
                totalGB?: number;
                expireTime?: number;
                createdAt?: string;
            }>;
            decryption?: string;
            address?: string;
            port?: number;
            network?: string;
        };
        streamSettings?: {
            network: string;
            security: string;
            realitySettings?: {
                dest: string;
                serverNames: string[];
                privateKey: string;
                shortIds: string[];
                fingerprint: string;
                spiderX?: string;
            };
            tcpSettings?: {
                header: {
                    type: string;
                };
                acceptProxyProtocol?: boolean;
            };
        };
        sniffing?: {
            enabled: boolean;
            destOverride: string[];
        };
        tag?: string;
        listen?: string;
    }>;
    outbounds: Array<{
        protocol: string;
        settings: Record<string, any>;
        tag: string;
    }>;
    routing?: {
        domainStrategy: string;
        rules: Array<{
            inboundTag?: string[];
            outboundTag: string;
            type: string;
        }>;
    };
}
//# sourceMappingURL=index.d.ts.map