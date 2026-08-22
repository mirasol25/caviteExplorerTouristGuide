import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  const port = Number(process.env.PORT || 3000);
  const configuredOrigins = [
    process.env.FRONTEND_URL,
    process.env.ADMIN_WEB_URL,
    ...(process.env.CORS_ORIGINS || '').split(','),
  ]
    .map((origin) => origin?.trim().replace(/\/$/, ''))
    .filter((origin): origin is string => Boolean(origin));

  app.enableCors({
    credentials: true,
    origin: (origin, callback) => {
      // Native mobile apps and server-to-server requests do not send Origin.
      if (!origin) return callback(null, true);
      const normalizedOrigin = origin.replace(/\/$/, '');
      const isLocalDevelopment =
        process.env.NODE_ENV !== 'production' &&
        /^https?:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$/.test(normalizedOrigin);
      callback(null, configuredOrigins.includes(normalizedOrigin) || isLocalDevelopment);
    },
  });
  app.useStaticAssets(join(process.cwd(), 'uploads'), {
    prefix: '/uploads/',
    maxAge: '7d',
    immutable: true,
  });

  await app.listen(port, '0.0.0.0');
  console.log(`Cavite Explorer Backend is listening on port ${port}`);
}
bootstrap();

