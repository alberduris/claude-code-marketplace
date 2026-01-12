#!/bin/bash
# Schedule a Slack reminder for a future date/time
# Usage: ./schedule-reminder.sh "<message>" "<datetime>"
# Datetime formats: "2026-01-17 10:00", "+1h", "+30m", "+2d", "tomorrow 09:00", "friday 14:30"

set -e

MESSAGE="$1"
DATETIME="$2"

if [[ -z "$MESSAGE" || -z "$DATETIME" ]]; then
  echo "Error: Usage: $0 \"<message>\" \"<datetime>\""
  exit 1
fi

# Load env var: .env.local → .env → shell env
load_env_var() {
  local var_name="$1"
  for env_file in .env.local .env; do
    if [[ -f "$env_file" ]]; then
      local value=$(grep "^${var_name}=" "$env_file" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"')
      if [[ -n "$value" ]]; then
        export "$var_name=$value"
        return
      fi
    fi
  done
  # Shell env is already set, nothing to do
}

load_env_var "SLACK_REMINDER_BOT_TOKEN"
load_env_var "SLACK_REMINDER_CHANNEL_ID"

if [[ -z "$SLACK_REMINDER_BOT_TOKEN" ]]; then
  echo "Error: SLACK_REMINDER_BOT_TOKEN not set (checked .env.local, .env, shell env)"
  exit 1
fi

if [[ -z "$SLACK_REMINDER_CHANNEL_ID" ]]; then
  echo "Error: SLACK_REMINDER_CHANNEL_ID not set (checked .env.local, .env, shell env)"
  exit 1
fi

# Parse datetime to Unix timestamp
parse_datetime() {
  local dt="$1"
  local now=$(date +%s)

  # Relative formats: +1h, +30m, +2d
  if [[ "$dt" =~ ^\+([0-9]+)([hmd])$ ]]; then
    local num="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[2]}"
    case "$unit" in
      h) echo $((now + num * 3600)) ;;
      m) echo $((now + num * 60)) ;;
      d) echo $((now + num * 86400)) ;;
    esac
    return
  fi

  # Try GNU date first (Linux), fall back to BSD date (macOS)
  if date --version >/dev/null 2>&1; then
    # GNU date
    date -d "$dt" +%s 2>/dev/null || { echo "Error: Could not parse datetime"; exit 1; }
  else
    # BSD date (macOS) - try direct parsing for ISO format
    if [[ "$dt" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2} ]]; then
      date -j -f "%Y-%m-%d %H:%M" "$dt" +%s 2>/dev/null || { echo "Error: Could not parse datetime"; exit 1; }
    else
      # For natural language, try with -j flag
      date -j -f "%Y-%m-%d %H:%M:%S" "$(date -j -v"$dt" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)" +%s 2>/dev/null || \
      { echo "Error: Could not parse datetime '$dt'. Use ISO format: 2026-01-17 10:00"; exit 1; }
    fi
  fi
}

POST_AT=$(parse_datetime "$DATETIME")

# Validate timestamp is in the future
NOW=$(date +%s)
if [[ "$POST_AT" -le "$NOW" ]]; then
  echo "Error: Datetime must be in the future"
  exit 1
fi

# Schedule the message
RESPONSE=$(curl -s -X POST "https://slack.com/api/chat.scheduleMessage" \
  -H "Authorization: Bearer $SLACK_REMINDER_BOT_TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data-raw "{\"channel\":\"$SLACK_REMINDER_CHANNEL_ID\",\"text\":\"$MESSAGE\",\"post_at\":$POST_AT}")

OK=$(echo "$RESPONSE" | grep -o '"ok":true' || true)

if [[ -n "$OK" ]]; then
  SCHEDULED_ID=$(echo "$RESPONSE" | grep -o '"scheduled_message_id":"[^"]*"' | cut -d'"' -f4)
  SCHEDULED_TIME=$(date -r "$POST_AT" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$POST_AT" "+%Y-%m-%d %H:%M" 2>/dev/null)
  echo "Reminder scheduled for $SCHEDULED_TIME (ID: $SCHEDULED_ID)"
else
  ERROR=$(echo "$RESPONSE" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
  echo "Error scheduling reminder: $ERROR"
  exit 1
fi
