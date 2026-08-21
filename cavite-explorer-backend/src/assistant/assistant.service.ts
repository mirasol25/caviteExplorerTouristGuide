import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AssistantService {
  constructor(private readonly config: ConfigService) {}

  async generate(prompt: string) {
    const apiKey = this.config.getOrThrow<string>('GROQ_API_KEY');
    const configuredModel = this.config
      .get<string>('GROQ_MODEL', 'openai/gpt-oss-120b')
      .trim();
    const models = [...new Set([configuredModel, 'llama-3.1-8b-instant'])];

    for (const [index, model] of models.entries()) {
      const response = await fetch(
        'https://api.groq.com/openai/v1/chat/completions',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model,
            messages: [
              {
                role: 'system',
                content:
                  'You are a careful local travel-planning assistant for Cavite, Philippines. Treat only facts in the user prompt as verified. Do not invent named businesses, transport routes, schedules, fares, or road conditions. If a detail is uncertain, use clear estimate wording or a generic activity. Follow every requested JSON field and allowed-value rule exactly. Output only valid JSON, with no Markdown or explanation.',
              },
              { role: 'user', content: prompt },
            ],
            response_format: { type: 'json_object' },
            temperature: 0.2,
            max_tokens: 1200,
          }),
        },
      );

      if (response.ok) {
        const data: any = await response.json();
        try {
          return JSON.parse(data.choices[0].message.content.trim());
        } catch {
          throw new InternalServerErrorException(
            'AI returned an invalid response',
          );
        }
      }

      const details = await response.text();
      const hasFallback = index < models.length - 1;
      const modelIsUnavailable =
        response.status === 404 && details.includes('model_not_found');
      if (modelIsUnavailable && hasFallback) {
        console.warn(
          `Groq model ${model} is unavailable; retrying with ${models[index + 1]}.`,
        );
        continue;
      }

      console.error(`Groq request failed (${response.status}): ${details}`);
      throw new InternalServerErrorException('Unable to generate AI guidance');
    }

    throw new InternalServerErrorException('Unable to generate AI guidance');
  }
}
