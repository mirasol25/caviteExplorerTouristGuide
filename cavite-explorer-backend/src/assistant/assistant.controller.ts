import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { NeonGuard } from '../auth/neon.guard';
import { AssistantService } from './assistant.service';

@Controller('assistant')
@UseGuards(NeonGuard)
export class AssistantController {
  constructor(private readonly assistant: AssistantService) {}

  @Post('generate')
  @HttpCode(HttpStatus.OK)
  generate(@Body() body: { prompt: string }) {
    return this.assistant.generate(body.prompt);
  }

}
