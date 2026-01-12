# Second Opinion

Consult GPT-5 Pro for alternative perspectives when you need a second opinion, peer review, or fresh take on technical decisions.

## Features

Context injection from multiple files · Web search capability (OpenAI responses API) · Configurable model selection (gpt-5-pro default) · Reasoning summary extraction · 30-minute timeout for complex queries · Calling agent retains final judgment authority

## Setup

```bash
export OPENAI_API_KEY="your-api-key-here"
```

Add to `~/.zshrc` or `~/.bashrc` and run `source ~/.zshrc`.

## Configuration (optional)

```bash
export SECOND_OPINION_MODEL="gpt-5-pro-2025-10-06"  # default model
export SECOND_OPINION_TIMEOUT="1800000"             # 30min timeout in ms
```

## Usage

Automatically triggered when requesting "second opinion", "peer review", or "alternative perspective".

## Requirements

`OPENAI_API_KEY` environment variable · Node.js/pnpm for TypeScript execution

## License

MIT
