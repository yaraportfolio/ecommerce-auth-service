import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import authRoutes from './routes/auth.js';
import { initDatabase } from './config/database.js';
import { metricsMiddleware, metricsEndpoint } from './middleware/metrics.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;
const SERVICE_NAME = 'auth-service';
const VERSION = '3.3';

const allowedOrigins = [
  'http://localhost:5173',
  'http://localhost',
  'http://e-commerce.local',
  process.env.FRONTEND_URL
].filter(Boolean);

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(null, true);
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(metricsMiddleware);

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: 'Too many requests, please try again later'
});
app.use('/api/', limiter);

app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const user = req.user?.email || req.body?.email || 'anonymous';
    const status = res.statusCode;
    const emoji = status < 400 ? '✅' : '❌';
    
    console.log(`${emoji} [${SERVICE_NAME}] ${req.method} ${req.path}
   User: ${user}
   Status: ${status}
   Duration: ${duration}ms`);
  });
  
  next();
});

app.get('/api/auth/metrics', metricsEndpoint);

app.get('/api/auth/health', async (req, res) => {
  const health = {
    status: 'ok',
    service: SERVICE_NAME,
    version: VERSION,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'production',
    database: 'disconnected'
  };

  try {
    const { getConnection } = await import('./config/database.js');
    const connection = await getConnection();
    await connection.query('SELECT 1');
    connection.release();
    health.database = 'connected';
  } catch (error) {
    health.database = 'error';
    health.status = 'degraded';
  }

  const statusCode = health.status === 'ok' ? 200 : 503;
  res.status(statusCode).json(health);
});

app.get('/api/auth/ready', async (req, res) => {
  try {
    const { getConnection } = await import('./config/database.js');
    const connection = await getConnection();
    await connection.query('SELECT 1');
    connection.release();
    res.json({ status: 'ready' });
  } catch (error) {
    res.status(503).json({ status: 'not ready', error: error.message });
  }
});

app.get('/api/auth/info', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    version: VERSION,
    description: 'Authentication and user management microservice',
    endpoints: [
      'GET  /api/auth/health - Health check',
      'GET  /api/auth/ready - Readiness probe',
      'GET  /api/auth/metrics - Prometheus metrics',
      'GET  /api/auth/info - Service information',
      'POST /api/auth/register - User registration',
      'POST /api/auth/login - User login',
      'GET  /api/auth/me - Get user info (requires auth)'
    ],
    dependencies: {
      database: 'MariaDB',
      cache: 'none'
    }
  });
});

app.use('/api/auth', authRoutes);

app.use((req, res) => {
  res.status(404).json({ error: 'Route non trouvée' });
});

app.use((err, req, res, next) => {
  console.error(`[${SERVICE_NAME}] Error:`, err);
  res.status(500).json({
    error: 'Erreur interne du serveur',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

const startServer = async () => {
  try {
    await initDatabase();

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`
╔═══════════════════════════════════════════════
║   🔐 ${SERVICE_NAME.toUpperCase()} - v${VERSION}
║
║   Port: ${PORT}
║   Environment: ${process.env.NODE_ENV || 'development'}
║   Database: ${process.env.DB_HOST || 'localhost'}:${process.env.DB_PORT || 3306}
║
║   📚 Endpoints:
║   GET  /api/auth/health       - Health check
║   GET  /api/auth/ready        - Ready check
║   GET  /api/auth/metrics      - Prometheus
║   GET  /api/auth/info         - Service info
║   POST /api/auth/register     - Inscription
║   POST /api/auth/login        - Connexion
║   GET  /api/auth/me           - Info user
║
╚═══════════════════════════════════════════════
      `);
    });
  } catch (error) {
    console.error(`❌ Failed to start ${SERVICE_NAME}:`, error);
    process.exit(1);
  }
};

startServer();