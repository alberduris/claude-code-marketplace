---
name: x
description: Interact with X (Twitter) API v2. Post tweets, read timeline, search, manage your account.
allowed-tools: Bash(node *)
---

# X API Skill

X (Twitter) API v2 via your own developer credentials (OAuth 1.0a, pay-per-use).

## Commands

| Command | Description | Docs |
|---------|-------------|------|
| `me` | Your account profile, metrics, verification status | [docs/me.md](docs/me.md) |

## Invocation

```
<base_directory>/x <command> [flags]
```

Read the command docs for available flags and examples.

## Credentials

Reads from `.env.local` > `.env` > environment variables in the plugin directory.

Required: `X_API_KEY`, `X_API_SECRET`, `X_ACCESS_TOKEN`, `X_ACCESS_TOKEN_SECRET`

Get these from [console.x.com](https://console.x.com) > Apps > Keys and tokens.
