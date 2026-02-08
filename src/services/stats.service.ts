// import { XrayService } from './xray.service';
// import { XrayUtils } from '../utils/xray.utils';
// import { UserStats, TrafficSummary } from '../types';
import { XtlsApi } from '@remnawave/xtls-sdk';

// Define interfaces based on SDK source
interface IUserStat {
  name?: string;
  email?: string;
  username?: string;
  uplink?: number;
  downlink?: number;
  uplinkBytes?: number;
  downlinkBytes?: number;
  tx?: number;
  rx?: number;
  connectionCount?: number;
  [key: string]: any;
}

// interface ISysStats {
//   numGoroutine: number;
//   numGC: number;
//   alloc: number;
//   totalAlloc: number;
//   sys: number;
//   mallocs: number;
//   frees: number;
//   liveObjects: number;
//   pauseTotalNs: number;
//   uptime: number;
// }

interface ISdkResponse<T> {
  isOk: boolean;
  data?: T;
  message?: string;
  code?: string;
}

interface GetAllUsersStatsResponseModel {
  users: IUserStat[];
}

// interface GetUserStatsResponseModel {
//   user: IUserStat | null;
// }

// interface GetSysStatsResponseModel extends ISysStats {}

export class StatsService {
  private static apiClient: XtlsApi | null = null;
  private static readonly XRAY_API_ADDRESS = '127.0.0.1';
  private static readonly XRAY_API_PORT = 10085;

  static async getAllStats(): Promise<string>{
      const api = await this.getClient();
      const response = await api.stats.getAllUsersStats() as ISdkResponse<GetAllUsersStatsResponseModel>;
      
      console.log('SDK getAllUsersStats response:', JSON.stringify(response, null, 2));
      return JSON.stringify(response, null, 2);

  }
  
//   // Initialize connection to Xray gRPC API
  private static async getClient(): Promise<XtlsApi> {
    if (!this.apiClient) {
      try {
        this.apiClient = new XtlsApi({
          connectionUrl: `${this.XRAY_API_ADDRESS}:${this.XRAY_API_PORT}`
        });
        console.log('✅ Connected to Xray gRPC API');
      } catch (error: any) {
        console.error('Failed to initialize Xray client:', error.message);
        throw error;
      }
    }
    return this.apiClient;
  }
  
//   // Get all stats from Xray using the SDK
//   static async getXrayStats(): Promise<Record<string, number>> {
//     try {
//       const api = await this.getClient();
//       const response = await api.stats.getAllUsersStats() as ISdkResponse<GetAllUsersStatsResponseModel>;
      
//       console.log('SDK getAllUsersStats response:', JSON.stringify(response, null, 2));
      
//       if (!response.isOk || !response.data) {
//         console.warn('Failed to get Xray stats:', response.message);
//         return {};
//       }

//       const formattedStats: Record<string, number> = {};
//       const statsData = response.data;
      
//       // The GetAllUsersStatsResponseModel has a 'users' array property
//       if (statsData.users && Array.isArray(statsData.users)) {
//         statsData.users.forEach((userStat: IUserStat) => {
//           const email = userStat.email || userStat.username || userStat.name;
//           if (email) {
//             // Map stats to Xray's expected format
//             if (userStat.uplink !== undefined) {
//               formattedStats[`user>>>${email}>>>traffic>>>uplink`] = userStat.uplink;
//             }
//             if (userStat.downlink !== undefined) {
//               formattedStats[`user>>>${email}>>>traffic>>>downlink`] = userStat.downlink;
//             }
//           }
//         });
//       }
      
//       // If no stats from SDK, fallback to config-based approach
//       if (Object.keys(formattedStats).length === 0) {
//         console.log('ℹ️  No user stats from SDK, using config-based approach');
//         return await this.getStatsFromConfig();
//       }
      
//       return formattedStats;
//     } catch (error: any) {
//       console.warn('Failed to get Xray stats via gRPC:', error.message);
//       return await this.getStatsFromConfig();
//     }
//   }
  
//   // Fallback: Get stats from config when SDK returns empty
//   private static async getStatsFromConfig(): Promise<Record<string, number>> {
//     try {
//       const config = await XrayService.getConfig();
//       const formattedStats: Record<string, number> = {};
      
//       // Extract users from config and create zero stats
//       for (const inbound of config.inbounds || []) {
//         if (inbound.settings?.clients) {
//           for (const client of inbound.settings.clients) {
//             const email = client.email || `user-${client.id}`;
//             formattedStats[`user>>>${email}>>>traffic>>>uplink`] = 0;
//             formattedStats[`user>>>${email}>>>traffic>>>downlink`] = 0;
//           }
//         }
//       }
      
//       return formattedStats;
//     } catch (error: any) {
//       console.warn('Failed to get stats from config:', error.message);
//       return {};
//     }
//   }
  
//   // Get stats for a specific user using the SDK
//   static async getUserStats(email: string): Promise<UserStats> {
//     try {
//       const api = await this.getClient();
      
//       // Call getUserStats with the username/email
//       const response = await api.stats.getUserStats(email) as ISdkResponse<GetUserStatsResponseModel>;
      
//       console.log(`SDK getUserStats response for ${email}:`, JSON.stringify(response, null, 2));
      
//       if (response.isOk && response.data && response.data.user) {
//         const userData = response.data.user;
        
//         // Extract uplink/downlink from IUserStat
//         const uplink = userData.uplink || userData.uplinkBytes || userData.tx || 0;
//         const downlink = userData.downlink || userData.downlinkBytes || userData.rx || 0;
        
//         return {
//           uplink,
//           downlink,
//           total: uplink + downlink
//         };
//       }
      
//       console.warn(`No stats for ${email} from SDK:`, response.message);
//       return { uplink: 0, downlink: 0, total: 0 };
      
//     } catch (error: any) {
//       console.warn(`Failed to get stats for ${email}:`, error.message);
//       return { uplink: 0, downlink: 0, total: 0 };
//     }
//   }
  
//   // Get traffic summary using SDK
//   static async getTrafficSummary(): Promise<TrafficSummary> {
//     try {
//       const api = await this.getClient();
      
//       // Try to get system stats first
//       const sysResponse = await api.stats.getSysStats() as ISdkResponse<GetSysStatsResponseModel>;
//       console.log('SDK getSysStats response:', JSON.stringify(sysResponse, null, 2));
      
//       let totalUplink = 0;
//       let totalDownlink = 0;
      
//       // IMPORTANT: According to GetSysStatsResponseModel, it only has system metrics,
//       // NOT traffic statistics. We need to use getAllUsersStats to calculate traffic.
//       const allUsersResponse = await api.stats.getAllUsersStats() as ISdkResponse<GetAllUsersStatsResponseModel>;
      
//       if (allUsersResponse.isOk && allUsersResponse.data && allUsersResponse.data.users) {
//         // Sum traffic from all users
//         allUsersResponse.data.users.forEach((userStat: IUserStat) => {
//           totalUplink += userStat.uplink || userStat.uplinkBytes || userStat.tx || 0;
//           totalDownlink += userStat.downlink || userStat.downlinkBytes || userStat.rx || 0;
//         });
//       }
      
//       return {
//         totalUplink,
//         totalDownlink,
//         totalTraffic: totalUplink + totalDownlink,
//         uplinkGB: totalUplink / (1024 * 1024 * 1024),
//         downlinkGB: totalDownlink / (1024 * 1024 * 1024),
//         totalGB: (totalUplink + totalDownlink) / (1024 * 1024 * 1024)
//       };
      
//     } catch (error: any) {
//       console.warn('Failed to get traffic summary:', error.message);
      
//       // Fallback to summing from parsed stats
//       const allStats = await this.getXrayStats();
//       let totalUplink = 0;
//       let totalDownlink = 0;
      
//       for (const [key, value] of Object.entries(allStats)) {
//         if (key.includes('traffic>>>uplink')) {
//           totalUplink += value;
//         } else if (key.includes('traffic>>>downlink')) {
//           totalDownlink += value;
//         }
//       }
      
//       return {
//         totalUplink,
//         totalDownlink,
//         totalTraffic: totalUplink + totalDownlink,
//         uplinkGB: totalUplink / (1024 * 1024 * 1024),
//         downlinkGB: totalDownlink / (1024 * 1024 * 1024),
//         totalGB: (totalUplink + totalDownlink) / (1024 * 1024 * 1024)
//       };
//     }
//   }
  
//   // Reset user stats using SDK
//   static async resetUserStats(email: string): Promise<boolean> {
//     try {
//       const api = await this.getClient();
      
//       // Pass true as second parameter to reset stats
//       const response = await api.stats.getUserStats(email, true) as ISdkResponse<GetUserStatsResponseModel>;
      
//       if (response.isOk) {
//         console.log(`✅ Reset stats for user: ${email}`);
//         return true;
//       } else {
//         console.warn(`Failed to reset stats for ${email}:`, response.message);
//         return false;
//       }
//     } catch (error: any) {
//       console.warn(`Failed to reset stats for ${email}:`, error.message);
//       return false;
//     }
//   }
  
//   // Get all users with their stats
//   static async getAllUsersWithStats(): Promise<{
//     users: any[];
//     trafficSummary: TrafficSummary;
//     totalUsers: number;
//   }> {
//     try {
//       const config = await XrayService.getConfig();
//       const api = await this.getClient();
      
//       // Get user stats from SDK
//       const userStatsMap = new Map<string, UserStats>();
//       const allUsersResponse = await api.stats.getAllUsersStats() as ISdkResponse<GetAllUsersStatsResponseModel>;
      
//       if (allUsersResponse.isOk && allUsersResponse.data && allUsersResponse.data.users) {
//         allUsersResponse.data.users.forEach((userStat: IUserStat) => {
//           const email = userStat.email || userStat.username || userStat.name;
//           if (email) {
//             const uplink = userStat.uplink || userStat.uplinkBytes || userStat.tx || 0;
//             const downlink = userStat.downlink || userStat.downlinkBytes || userStat.rx || 0;
            
//             userStatsMap.set(email, {
//               uplink,
//               downlink,
//               total: uplink + downlink
//             });
//           }
//         });
//       }
      
//       // Get traffic summary
//       const trafficSummary = await this.getTrafficSummary();
      
//       // Extract users from config and combine with stats
//       const users = XrayUtils.extractUsersFromConfig(config, userStatsMap);
      
//       return {
//         users,
//         trafficSummary,
//         totalUsers: users.length
//       };
//     } catch (error: any) {
//       console.error('Error getting all users with stats:', error.message);
      
//       return {
//         users: [],
//         trafficSummary: { 
//           totalUplink: 0, 
//           totalDownlink: 0, 
//           totalTraffic: 0,
//           uplinkGB: 0,
//           downlinkGB: 0,
//           totalGB: 0
//         },
//         totalUsers: 0
//       };
//     }
//   }
  
//   // Check user online status using SDK
//   static async getUserOnlineStatus(email: string): Promise<boolean> {
//     try {
//       const api = await this.getClient();
//       const response = await api.stats.getUserOnlineStatus(email);
      
//       if (response.isOk && response.data !== undefined) {
//         // Check if response.data has an 'online' property
//         const data = response.data as any;
//         return data.online === true || data.online === 'true';
//       }
//       return false;
//     } catch (error: any) {
//       console.warn(`Failed to check online status for ${email}:`, error.message);
//       return false;
//     }
//   }
  
//   // Test connection to Xray API
//   static async testConnection(): Promise<boolean> {
//     try {
//       const api = await this.getClient();
      
//       // Try a simple API call to test connection
//       const response = await api.stats.getSysStats();
      
//       if (response.isOk) {
//         console.log('✅ Xray gRPC API connection test passed');
//         return true;
//       } else {
//         console.log('❌ Xray gRPC API test failed:', response.message);
//         return false;
//       }
//     } catch (error: any) {
//       console.error('❌ Xray gRPC API connection failed:', error.message);
//       return false;
//     }
//   }
  
//   // Get system information
//   static async getSystemInfo(): Promise<any> {
//     try {
//       const api = await this.getClient();
//       const response = await api.stats.getSysStats() as ISdkResponse<GetSysStatsResponseModel>;
      
//       if (response.isOk && response.data) {
//         const sysData = response.data;
        
//         // System stats from GetSysStatsResponseModel
//         return {
//           // Memory and GC stats
//           numGoroutine: sysData.numGoroutine,
//           numGC: sysData.numGC,
//           alloc: sysData.alloc,
//           totalAlloc: sysData.totalAlloc,
//           sys: sysData.sys,
//           mallocs: sysData.mallocs,
//           frees: sysData.frees,
//           liveObjects: sysData.liveObjects,
//           pauseTotalNs: sysData.pauseTotalNs,
          
//           // Uptime in seconds
//           uptime: sysData.uptime,
//           uptimeFormatted: this.formatUptime(sysData.uptime),
          
//           timestamp: new Date().toISOString()
//         };
//       }
      
//       return {
//         timestamp: new Date().toISOString(),
//         error: response.message || 'Failed to get system info'
//       };
//     } catch (error: any) {
//       console.warn('Failed to get system info:', error.message);
//       return {
//         timestamp: new Date().toISOString(),
//         error: error.message
//       };
//     }
//   }
  
//   // Format uptime from seconds to human readable
//   private static formatUptime(seconds: number): string {
//     const days = Math.floor(seconds / 86400);
//     const hours = Math.floor((seconds % 86400) / 3600);
//     const minutes = Math.floor((seconds % 3600) / 60);
//     const secs = Math.floor(seconds % 60);
    
//     const parts = [];
//     if (days > 0) parts.push(`${days}d`);
//     if (hours > 0) parts.push(`${hours}h`);
//     if (minutes > 0) parts.push(`${minutes}m`);
//     if (secs > 0 || parts.length === 0) parts.push(`${secs}s`);
    
//     return parts.join(' ');
//   }
  
//   // Get inbound statistics
//   static async getInboundStats(inboundTag?: string): Promise<any> {
//     try {
//       const api = await this.getClient();
      
//       if (inboundTag) {
//         const response = await api.stats.getInboundStats(inboundTag);
//         return response;
//       } else {
//         const response = await api.stats.getAllInboundsStats();
//         return response;
//       }
//     } catch (error: any) {
//       console.warn('Failed to get inbound stats:', error.message);
//       return { isOk: false, message: error.message };
//     }
//   }
  
//   // Get outbound statistics
//   static async getOutboundStats(outboundTag?: string): Promise<any> {
//     try {
//       const api = await this.getClient();
      
//       if (outboundTag) {
//         const response = await api.stats.getOutboundStats(outboundTag);
//         return response;
//       } else {
//         const response = await api.stats.getAllOutboundsStats();
//         return response;
//       }
//     } catch (error: any) {
//       console.warn('Failed to get outbound stats:', error.message);
//       return { isOk: false, message: error.message };
//     }
//   }
  
//   // Debug method to test all SDK methods
//   static async debugSDK(): Promise<void> {
//     try {
//       const api = await this.getClient();
      
//       console.log('🔍 Testing all SDK methods with correct structure...');
      
//       // Test 1: System stats
//       console.log('\n1. Testing getSysStats():');
//       const sysStats = await api.stats.getSysStats() as ISdkResponse<GetSysStatsResponseModel>;
//       if (sysStats.isOk && sysStats.data) {
//         console.log('System stats keys:', Object.keys(sysStats.data));
//         console.log('Uptime:', sysStats.data.uptime, 'seconds');
//         console.log('Full response:', JSON.stringify(sysStats, null, 2));
//       }
      
//       // Test 2: All users stats
//       console.log('\n2. Testing getAllUsersStats():');
//       const allUsers = await api.stats.getAllUsersStats() as ISdkResponse<GetAllUsersStatsResponseModel>;
//       if (allUsers.isOk && allUsers.data) {
//         console.log('Users array length:', allUsers.data.users.length);
//         if (allUsers.data.users.length > 0) {
//           console.log('First user structure:', JSON.stringify(allUsers.data.users[0], null, 2));
//           console.log('Available user properties:', Object.keys(allUsers.data.users[0]));
//         }
//         console.log('Full response:', JSON.stringify(allUsers, null, 2));
//       }
      
//       // Test 3: Get user stats for config users
//       console.log('\n3. Testing getUserStats():');
//       const config = await XrayService.getConfig();
//       for (const inbound of config.inbounds || []) {
//         if (inbound.settings?.clients) {
//           for (const client of inbound.settings.clients) {
//             const email = client.email || `user-${client.id}`;
//             console.log(`\n   Testing getUserStats("${email}"):`);
//             const userStats = await api.stats.getUserStats(email) as ISdkResponse<GetUserStatsResponseModel>;
//             if (userStats.isOk && userStats.data) {
//               console.log('   Has user data:', userStats.data.user !== null);
//               if (userStats.data.user) {
//                 console.log('   User properties:', Object.keys(userStats.data.user));
//                 console.log('   User data:', JSON.stringify(userStats.data.user, null, 2));
//               }
//             }
//           }
//         }
//       }
      
//     } catch (error: any) {
//       console.error('Debug failed:', error.message);
//     }
//   }
  
//   // Close connection (cleanup)
//   static async close(): Promise<void> {
//     this.apiClient = null;
//     console.log('✅ Cleared Xray API client reference');
//   }
}