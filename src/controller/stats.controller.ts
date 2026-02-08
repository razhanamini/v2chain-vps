import { Request, Response } from 'express';
import { StatsService } from '../services/stats.service';

export class StatsController {
  static async getAllStats(_req: Request, res: Response) {
    try {
      const stats = await StatsService.getAllStats();
      // const trafficSummary = await StatsService.getTrafficSummary();
      
      // const activeConnections = Object.keys(stats).filter(
      //   key => key.includes('connection') && !key.includes('reset')
      // ).length;


      
      res.json({
        success: true,
        data: stats
      });
      
    } catch (error: any) {
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