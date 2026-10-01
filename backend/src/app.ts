import express, { type ErrorRequestHandler } from 'express';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '32kb' }));

  // Solo disponibilidad del proceso; no implica conexión a datos ni servicios.
  app.get('/api/health', (_req, res) => {
    res.status(200).json({ status: 'ok', service: 'vitalia-api' });
  });

  app.use((_req, res) => {
    res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Recurso no disponible.' } });
  });

  const handleError: ErrorRequestHandler = (error, _req, res, next) => {
    if (res.headersSent) { next(error); return; }
    const status = error?.type === 'entity.too.large' ? 413
      : error?.type === 'entity.parse.failed' ? 400 : 500;
    res.status(status).json({ error: {
      code: status === 413 ? 'PAYLOAD_TOO_LARGE' : status === 400 ? 'INVALID_JSON' : 'INTERNAL_ERROR',
      message: status === 413 ? 'Solicitud demasiado grande.'
        : status === 400 ? 'La solicitud contiene JSON inválido.' : 'No se pudo completar la solicitud.',
    } });
  };
  app.use(handleError);
  return app;
}
