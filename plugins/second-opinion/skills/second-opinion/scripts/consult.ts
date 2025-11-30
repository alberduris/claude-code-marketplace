#!/usr/bin/env node

import { readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

interface Args {
  message: string;
  files?: string[];
}

function loadApiKey(): string | undefined {
  // Try .env.local first
  const envLocalPath = resolve(process.cwd(), '.env.local');
  if (existsSync(envLocalPath)) {
    const content = readFileSync(envLocalPath, 'utf-8');
    const match = content.match(/^OPENAI_API_KEY=(.+)$/m);
    if (match) return match[1].trim();
  }

  // Try .env second
  const envPath = resolve(process.cwd(), '.env');
  if (existsSync(envPath)) {
    const content = readFileSync(envPath, 'utf-8');
    const match = content.match(/^OPENAI_API_KEY=(.+)$/m);
    if (match) return match[1].trim();
  }

  // Fall back to system environment variable
  return process.env.OPENAI_API_KEY;
}

function parseArgs(): Args {
  const args = process.argv.slice(2);
  let message = '';
  let files: string[] = [];

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--message' && args[i + 1]) {
      message = args[i + 1];
      i++;
    } else if (args[i] === '--files' && args[i + 1]) {
      files = args[i + 1].split(',').map(f => f.trim());
      i++;
    }
  }

  if (!message) {
    console.error('Error: --message required');
    process.exit(1);
  }

  return { message, files };
}

function buildPrompt(message: string, files?: string[]): string {
  let prompt = message;

  if (files && files.length > 0) {
    prompt += '\n\n---\n\n# Context Files\n\n';

    for (const filePath of files) {
      try {
        const absolutePath = resolve(filePath);
        const content = readFileSync(absolutePath, 'utf-8');
        prompt += `\n## ${filePath}\n\n\`\`\`\n${content}\n\`\`\`\n\n`;
      } catch (error) {
        console.error(`Warning: Could not read file ${filePath}:`, error instanceof Error ? error.message : error);
      }
    }
  }

  return prompt;
}

async function main() {
  const { message, files } = parseArgs();

  const apiKey = loadApiKey();
  if (!apiKey) {
    console.error('Error: OPENAI_API_KEY not found. Checked: .env.local, .env, system environment');
    process.exit(1);
  }

  const model = process.env.SECOND_OPINION_MODEL || 'gpt-5-pro-2025-10-06';
  const timeoutMs = parseInt(process.env.SECOND_OPINION_TIMEOUT || '1800000', 10);
  const prompt = buildPrompt(message, files);

  const requestBody = {
    model,
    input: [
      {
        role: 'developer',
        content: 'Peer SWE consultant; use web search when helpful.'
      },
      {
        role: 'user',
        content: prompt
      }
    ],
    tools: [
      {
        type: 'web_search',
        user_location: { type: 'approximate' },
        search_context_size: 'medium'
      }
    ],
    store: false
  };

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    const response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify(requestBody),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Error: API request failed with status ${response.status}`);
      console.error(errorText);
      process.exit(1);
    }

    const data = await response.json();

    console.log('\n=== PEER CONSULTANT RESPONSE ===\n');

    // Extract response text
    console.log('## Response\n');
    const responseText = data.output_text ||
                        data.output?.find((o: any) => o.type === 'message')?.content?.[0]?.text ||
                        'No response generated';
    console.log(responseText);

    // Extract web search sources if present
    const webSearchOutput = data.output?.find((o: any) => o.type === 'web_search_call');
    if (webSearchOutput?.action?.sources) {
      console.log('\n## Sources Used\n');
      webSearchOutput.action.sources.forEach((source: { url: string; title?: string }) => {
        console.log(`- ${source.title || source.url}`);
        console.log(`  ${source.url}`);
      });
    }

  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      console.error('Error: Request timed out');
    } else {
      console.error('Error calling peer consultant:', error instanceof Error ? error.message : error);
    }
    process.exit(1);
  }
}

main();
