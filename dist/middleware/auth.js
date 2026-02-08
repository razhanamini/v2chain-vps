"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.staticTokenAuth = staticTokenAuth;
// Configuration - Set this via environment variable in production
const STATIC_TOKEN = process.env.API_STATIC_TOKEN || 'BviUVBkhZH2YdydyGiREet3f8vfWyEpGi5i2ozwOsGPVlXD6KKvxkXkXZ063mQV8';
function staticTokenAuth(req, res, next) {
    // Get token from headers
    const token = req.headers['x-api-token'] ||
        req.headers['authorization']?.replace('Bearer ', '');
    // Skip auth in development if needed (optional)
    if (process.env.NODE_ENV === 'development' && process.env.SKIP_AUTH === 'true') {
        return next();
    }
    // Check if token exists
    if (!token) {
        res.status(401).json({
            success: false,
            error: 'Authentication token required',
            timestamp: new Date().toISOString()
        });
        return;
    }
    // Validate token
    if (token !== STATIC_TOKEN) {
        console.warn(`Invalid token attempt from ${req.ip}`);
        res.status(403).json({
            success: false,
            error: 'Invalid authentication token',
            timestamp: new Date().toISOString()
        });
        return;
    }
    // Add user context to request (optional)
    req.user = {
        authenticated: true,
        authMethod: 'static-token'
    };
    next();
}
//# sourceMappingURL=auth.js.map