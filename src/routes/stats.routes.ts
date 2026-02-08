import { Router } from 'express';
import { StatsController } from '../controller/stats.controller';

const router = Router();

router.get('/status', StatsController.getAllStats);

export default router;