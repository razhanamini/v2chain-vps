import express from 'express';
import cors from 'cors';
import routes from './routes';

const app = express();
const PORT = 5000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Routes
app.use('/', routes);


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
  server.on('error', (error: any) => {
    if (error.code === 'EADDRINUSE') {
      console.error(`❌ Port ${PORT} is already in use!`);
      console.error('Try:');
      console.error(`   1. Kill the process using port ${PORT}`);
      console.error(`   2. Change PORT in app.ts to a different number`);
      console.error(`   3. Wait a minute and try again`);
    } else {
      console.error('Server error:', error);
    }
    process.exit(1);
  });
};

startServer().catch(console.error);

export default app;