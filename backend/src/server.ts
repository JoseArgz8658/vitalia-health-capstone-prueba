import { createApp } from './app';
import { readConfig } from './config';

try {
  const config = readConfig(process.env);
  const server = createApp().listen(config.PORT, config.HOST);
  server.on('listening', () => console.info('Vitalia API iniciada en el entorno local.'));
  server.on('error', () => {
    console.error('No se pudo iniciar el servidor. Revisa el puerto y la dirección configurados.');
    process.exitCode = 1;
  });
  const shutdown = () => server.close(() => { process.exitCode = 0; });
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
} catch {
  console.error('Configuración inválida. Revisa HOST y PORT.');
  process.exitCode = 1;
}
