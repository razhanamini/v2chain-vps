import { Router } from 'express';
import { ConfigController } from '../controller/config.controller';

const router = Router();

router.get('/config', ConfigController.getConfig);
router.put('/config', ConfigController.updateConfig);
router.post('/restart', ConfigController.restartService);

export default router;