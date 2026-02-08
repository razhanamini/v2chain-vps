"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const routes_1 = __importDefault(require("./routes"));
const app = (0, express_1.default)();
const PORT = 5000;
// Middleware
app.use((0, cors_1.default)());
app.use(express_1.default.json({ limit: '10mb' }));
// Routes
app.use('/', routes_1.default);
// Start server
const startServer = async () => {
    // Run basic checks on startup (before server starts)
    // Start the server first
    const server = app.listen(PORT, () => {
        console.log(`🚀 Xray Dashboard Backend running on http://localhost:${PORT}`);
        console.log(`📊 Health check: http://localhost:${PORT}/health`);
        console.log(`📋 Detailed health: http://localhost:${PORT}/health/detailed`);
        console.log(`📁 Config path: /usr/local/etc/xray/config.json`);
    });
    // Handle server errors
    server.on('error', (error) => {
        if (error.code === 'EADDRINUSE') {
            console.error(`❌ Port ${PORT} is already in use!`);
            console.error('Try:');
            console.error(`   1. Kill the process using port ${PORT}`);
            console.error(`   2. Change PORT in app.ts to a different number`);
            console.error(`   3. Wait a minute and try again`);
        }
        else {
            console.error('Server error:', error);
        }
        process.exit(1);
    });
};
startServer().catch(console.error);
exports.default = app;
//# sourceMappingURL=app.js.map