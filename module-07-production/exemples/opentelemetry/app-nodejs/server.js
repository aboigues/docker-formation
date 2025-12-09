import './tracing.js';
import express from 'express';
import { trace, metrics, SpanStatusCode } from '@opentelemetry/api';

const app = express();
const PORT = process.env.PORT || 8080;

// Obtenir le tracer et le meter
const tracer = trace.getTracer('demo-app');
const meter = metrics.getMeter('demo-app');

// Créer des métriques personnalisées
const requestCounter = meter.createCounter('http_requests_total', {
  description: 'Total number of HTTP requests',
});

const requestDuration = meter.createHistogram('http_request_duration_seconds', {
  description: 'HTTP request duration in seconds',
});

// Middleware pour mesurer la durée des requêtes
app.use((req, res, next) => {
  const startTime = Date.now();

  res.on('finish', () => {
    const duration = (Date.now() - startTime) / 1000;

    requestCounter.add(1, {
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode,
    });

    requestDuration.record(duration, {
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode,
    });
  });

  next();
});

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'Hello OpenTelemetry!' });
});

app.get('/api/users', async (req, res) => {
  const span = tracer.startSpan('get-users');

  try {
    // Simuler un appel à une base de données
    await simulateDbQuery('SELECT * FROM users', 100);

    const users = [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' },
    ];

    span.setAttributes({
      'db.system': 'postgresql',
      'db.operation': 'SELECT',
      'user.count': users.length,
    });

    span.setStatus({ code: SpanStatusCode.OK });
    res.json(users);
  } catch (error) {
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    });
    span.recordException(error);
    res.status(500).json({ error: 'Internal Server Error' });
  } finally {
    span.end();
  }
});

app.get('/api/users/:id', async (req, res) => {
  const span = tracer.startSpan('get-user-by-id');
  const userId = req.params.id;

  try {
    span.setAttribute('user.id', userId);

    // Simuler un appel à une base de données
    await simulateDbQuery(`SELECT * FROM users WHERE id = ${userId}`, 50);

    // Simuler un appel à un service externe
    const childSpan = tracer.startSpan('fetch-user-permissions', {
      parent: span,
    });

    await simulateExternalCall('permissions-service', 30);
    childSpan.end();

    const user = { id: userId, name: 'User ' + userId };

    span.setStatus({ code: SpanStatusCode.OK });
    res.json(user);
  } catch (error) {
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    });
    span.recordException(error);
    res.status(500).json({ error: 'Internal Server Error' });
  } finally {
    span.end();
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Fonctions utilitaires pour simuler des opérations
async function simulateDbQuery(query, delay) {
  const span = tracer.startSpan('database.query');
  span.setAttributes({
    'db.statement': query,
    'db.system': 'postgresql',
  });

  await new Promise(resolve => setTimeout(resolve, delay));
  span.end();
}

async function simulateExternalCall(service, delay) {
  const span = tracer.startSpan('http.request');
  span.setAttributes({
    'http.method': 'GET',
    'http.url': `http://${service}/api`,
  });

  await new Promise(resolve => setTimeout(resolve, delay));
  span.end();
}

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
