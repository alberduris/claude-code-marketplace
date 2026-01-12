# Langfuse Traces

Query Langfuse traces for debugging LLM calls, analyzing token usage, and investigating workflow executions.

## Commands

`traces [limit] [session_id] [name]` list recent traces · `trace <trace_id>` get full trace with observations · `observations [limit] [trace_id]` list spans/generations · `sessions [limit]` list sessions · `summary [limit]` compact one-line-per-trace view

## Setup

```bash
export LANGFUSE_PUBLIC_KEY="pk-lf-..."
export LANGFUSE_SECRET_KEY="sk-lf-..."
export LANGFUSE_BASE_URL="https://cloud.langfuse.com"  # optional, default
```

Add to `~/.zshrc` or `~/.bashrc` and run `source ~/.zshrc`.

## Requirements

`curl` and `jq` (standard on macOS/Linux) · Langfuse credentials

## License

MIT
