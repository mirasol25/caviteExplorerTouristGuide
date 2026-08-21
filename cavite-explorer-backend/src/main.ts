import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Enable CORS so your frontend web app can securely call this API
  app.enableCors();
  app.useStaticAssets(join(process.cwd(), 'uploads'), { prefix: '/uploads/' });

  // Start the server on port 3000
  await app.listen(3000, '0.0.0.0');
  console.log(`🚀 Cavite Explorer Backend is running on: http://localhost:3000`);
}
bootstrap();

