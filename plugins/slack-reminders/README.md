# Slack Reminders

Schedule future reminders via Slack. Tell Claude "remind me to X on Friday at 10am" and get a Slack notification at that exact time.

## Setup

### 1. Slack App

If you already have a Slack bot with `chat:write` scope, skip to step 2.

Otherwise: go to [api.slack.com/apps](https://api.slack.com/apps) → Create New App → From scratch → OAuth & Permissions → Add scopes `chat:write` and `chat:write.public` → Install to Workspace → Copy the Bot Token (`xoxb-...`).

### 2. Channel

Create or choose a channel for reminders. Invite your bot to the channel (`/invite @YourBot`). Get the channel ID: right-click channel → Copy link → ID is the last part of the URL (e.g., `C0123456789`).

### 3. Environment Variables

```bash
SLACK_REMINDER_BOT_TOKEN="xoxb-your-bot-token"
SLACK_REMINDER_CHANNEL_ID="C0123456789"
```

Add to `.env.local`, `.env`, or shell env (`~/.zshrc`). Priority: `.env.local` → `.env` → shell.

## Usage

Tell Claude naturally: "remind me to review the PR tomorrow at 9am", "ping me on Friday at 2pm", "notify me in 2 hours".

## Datetime Formats

ISO `2026-01-17 10:00` · Relative `+1h` `+30m` `+2d` · Natural `tomorrow 09:00` `friday 14:30`

## Requirements

`curl` (standard on macOS/Linux)

## License

MIT
