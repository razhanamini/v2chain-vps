import { Request, Response } from 'express';
import { XrayService } from '../services/xray.service';

export class ConfigController {
  static async getConfig(_req: Request, res: Response) {
    try {
      console.log('Getting Xray config...');
      
      const config = await XrayService.getConfig();
      
      res.json({
        success: true,
        config
      });
      
    } catch (error: any) {
      console.error('Error reading config:', error);
      res.status(500).json({ 
        success: false, 
        error: error.message 
      });
    }
  }
  
  static async updateConfig(req: Request, res: Response) {
    try {
      const config = req.body.config || req.body;
      
      console.log('Updating Xray config...');
      
      const backupPath = await XrayService.updateConfig(config);
      
      res.json({ 
        success: true, 
        message: 'Config updated successfully',
        backup: backupPath
      });
      
    } catch (error: any) {
      console.error('Error updating config:', error);
      res.status(500).json({ 
        success: false, 
        error: error.message 
      });
    }
  }
  
  static async restartService(_req: Request, res: Response) {
    try {
      console.log('Restarting Xray service...');
      
      const result = await XrayService.restartService();
      
      res.json({ 
        success: result.success,
        message: result.success ? 
          'Service restarted successfully' : 
          'Service may not be running',
        output: result.output
      });
      
    } catch (error: any) {
      console.error('Error restarting service:', error);
      res.status(500).json({ 
        success: false, 
        error: error.message 
      });
    }
  }
}