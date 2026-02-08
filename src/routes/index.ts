import { Router } from 'express';
import configRoutes from './config.routes';
import statsRoutes from './stats.routes';
import { staticTokenAuth } from '../middleware/auth';

const router = Router();
router.use('/api/xray', staticTokenAuth);
router.use('/api/xray', configRoutes);
router.use('/api/xray', statsRoutes);

export default router;