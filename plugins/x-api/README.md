# X API

Interact with X (Twitter) API v2 directly from Claude Code using your own developer credentials and pay-per-use pricing.

## Features

- `me` — Get authenticated user info

## Setup

### 1. Create an X Developer App

1. Go to [console.x.com](https://console.x.com) → **Apps** → Create a new App
2. Under **User authentication settings**, enable **OAuth 1.0a** with **Read and Write** permissions
3. Go to **Keys and tokens** and generate your credentials

### 2. Configure credentials

Copy the example env file and fill in your credentials:

```bash
cp .env.example .env.local
```

Edit `.env.local`:

```
X_API_KEY=your-api-key
X_API_SECRET=your-api-secret
X_ACCESS_TOKEN=your-access-token
X_ACCESS_TOKEN_SECRET=your-access-token-secret
```

### 3. Install and build

```bash
npm install
npm run build
```

## Usage

```bash
# Get your account info
bash skills/x/scripts/run.sh me
```

Or via Claude Code: `/x me`

## Requirements

- Node.js 18+
- X Developer account with OAuth 1.0a credentials

## License

MIT
