#!/bin/bash
#
# Second Opinion - Consult peer LLM (GPT-5 Pro by default)
#
# Usage: ./consult.sh --message "your question" [--files file1,file2,...]
#

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

DEFAULT_MODEL="gpt-5-pro-2025-10-06"
DEFAULT_TIMEOUT=1800  # 30 minutes in seconds
API_ENDPOINT="https://api.openai.com/v1/responses"

# -----------------------------------------------------------------------------
# JSON Parsing (graceful degradation)
# -----------------------------------------------------------------------------

extract_response_text() {
  local json="$1"

  if command -v jq &>/dev/null; then
    echo "$json" | jq -r '.output_text // (.output[] | select(.type=="message") | .content[0].text) // empty'
  elif command -v python3 &>/dev/null; then
    echo "$json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('output_text'):
    print(d['output_text'])
else:
    for o in d.get('output', []):
        if o.get('type') == 'message':
            print(o.get('content', [{}])[0].get('text', ''))
            break
"
  elif command -v node &>/dev/null; then
    echo "$json" | node -e "
const d=JSON.parse(require('fs').readFileSync(0,'utf8'));
const t=d.output_text||(d.output?.find(o=>o.type==='message')?.content?.[0]?.text)||'';
console.log(t);
"
  else
    # No parser available - return raw JSON (user sees everything, better than nothing)
    echo "[Note: Install jq for cleaner output]" >&2
    echo "$json"
  fi
}

# -----------------------------------------------------------------------------
# JSON Escape (bash pure fallback)
# -----------------------------------------------------------------------------

json_escape() {
  local str="$1"
  str="${str//\\/\\\\}"      # Backslashes first
  str="${str//\"/\\\"}"      # Quotes
  str="${str//$'\n'/\\n}"    # Newlines
  str="${str//$'\t'/\\t}"    # Tabs
  str="${str//$'\r'/\\r}"    # Carriage returns
  str="${str//$'\f'/\\f}"    # Form feed
  str="${str//$'\b'/\\b}"    # Backspace
  printf '%s' "$str"
}

# -----------------------------------------------------------------------------
# JSON Construction (graceful degradation: jq -> python3 -> bash)
# -----------------------------------------------------------------------------

build_request_json() {
  local prompt="$1"
  local model="$2"

  if command -v jq &>/dev/null; then
    jq -n \
      --arg model "$model" \
      --arg prompt "$prompt" \
      '{
        model: $model,
        input: [
          {role: "developer", content: "Peer SWE consultant; use web search when helpful."},
          {role: "user", content: $prompt}
        ],
        tools: [{type: "web_search", user_location: {type: "approximate"}, search_context_size: "medium"}],
        store: false
      }'
  elif command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
print(json.dumps({
    'model': sys.argv[1],
    'input': [
        {'role': 'developer', 'content': 'Peer SWE consultant; use web search when helpful.'},
        {'role': 'user', 'content': sys.argv[2]}
    ],
    'tools': [{'type': 'web_search', 'user_location': {'type': 'approximate'}, 'search_context_size': 'medium'}],
    'store': False
}))
" "$model" "$prompt"
  else
    # Fallback: bash pure (handles most common cases)
    local escaped_model escaped_prompt
    escaped_model=$(json_escape "$model")
    escaped_prompt=$(json_escape "$prompt")
    printf '%s' '{"model":"'"$escaped_model"'","input":[{"role":"developer","content":"Peer SWE consultant; use web search when helpful."},{"role":"user","content":"'"$escaped_prompt"'"}],"tools":[{"type":"web_search","user_location":{"type":"approximate"},"search_context_size":"medium"}],"store":false}'
  fi
}

# -----------------------------------------------------------------------------
# API Key Loading
# -----------------------------------------------------------------------------

load_api_key() {
  local key=""

  # Try .env.local first
  if [[ -f ".env.local" ]]; then
    key=$(grep -E "^OPENAI_API_KEY=" .env.local 2>/dev/null | cut -d= -f2- | tr -d "\"'" || true)
  fi

  # Try .env second
  if [[ -z "$key" && -f ".env" ]]; then
    key=$(grep -E "^OPENAI_API_KEY=" .env 2>/dev/null | cut -d= -f2- | tr -d "\"'" || true)
  fi

  # Fall back to environment variable
  if [[ -z "$key" ]]; then
    key="${OPENAI_API_KEY:-}"
  fi

  echo "$key"
}

# -----------------------------------------------------------------------------
# Utility: trim whitespace (bash native, no xargs)
# -----------------------------------------------------------------------------

trim() {
  local str="$1"
  str="${str#"${str%%[![:space:]]*}"}"  # trim leading
  str="${str%"${str##*[![:space:]]}"}"  # trim trailing
  printf '%s' "$str"
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------

MESSAGE=""
FILES=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --message)
      [[ -z "${2:-}" ]] && { echo "Error: --message requires a value" >&2; exit 1; }
      MESSAGE="$2"
      shift 2
      ;;
    --files)
      [[ -z "${2:-}" ]] && { echo "Error: --files requires a value" >&2; exit 1; }
      FILES=$(trim "$2")
      [[ -z "$FILES" ]] && { echo "Error: --files requires a value" >&2; exit 1; }
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MESSAGE" ]]; then
  echo "Error: --message is required" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Build Prompt
# -----------------------------------------------------------------------------

PROMPT="$MESSAGE"

if [[ -n "$FILES" ]]; then
  PROMPT+=$'\n\n---\n\n# Context Files\n'

  IFS=',' read -ra FILE_ARRAY <<< "$FILES"
  for file in "${FILE_ARRAY[@]}"; do
    file=$(trim "$file")
    if [[ -f "$file" && -r "$file" ]]; then
      content=$(cat "$file") || { echo "Warning: Could not read: $file" >&2; continue; }
      PROMPT+=$'\n## '"$file"$'\n\n```\n'"$content"$'\n```\n'
    elif [[ -f "$file" ]]; then
      echo "Warning: File not readable: $file" >&2
    else
      echo "Warning: File not found: $file" >&2
    fi
  done
fi

# -----------------------------------------------------------------------------
# Load Configuration
# -----------------------------------------------------------------------------

API_KEY=$(load_api_key)
if [[ -z "$API_KEY" ]]; then
  echo "Error: OPENAI_API_KEY not found. Checked: .env.local, .env, environment" >&2
  exit 1
fi

MODEL="${SECOND_OPINION_MODEL:-$DEFAULT_MODEL}"
TIMEOUT="${SECOND_OPINION_TIMEOUT:-$DEFAULT_TIMEOUT}"

# Validate timeout is numeric
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "Error: SECOND_OPINION_TIMEOUT must be a positive integer (got: $TIMEOUT)" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Build Request Body (using jq/python for proper JSON escaping)
# -----------------------------------------------------------------------------

REQUEST_BODY=$(build_request_json "$PROMPT" "$MODEL")

# -----------------------------------------------------------------------------
# Make Request
# -----------------------------------------------------------------------------

TMPFILE=""
ERRFILE=""
cleanup() { rm -f "$TMPFILE" "$ERRFILE"; }
trap cleanup EXIT
TMPFILE=$(mktemp) || { echo "Error: Failed to create temp file" >&2; exit 1; }
ERRFILE=$(mktemp) || { echo "Error: Failed to create temp file" >&2; exit 1; }

HTTP_CODE=$(curl -s -w "%{http_code}" --max-time "$TIMEOUT" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "$REQUEST_BODY" \
  -o "$TMPFILE" \
  "$API_ENDPOINT" 2>"$ERRFILE")

CURL_EXIT=$?

if [[ $CURL_EXIT -ne 0 ]]; then
  echo "Error: curl failed with exit code $CURL_EXIT" >&2
  [[ -s "$ERRFILE" ]] && cat "$ERRFILE" >&2
  [[ -s "$TMPFILE" ]] && cat "$TMPFILE" >&2
  exit 1
fi

RESPONSE=$(cat "$TMPFILE") || { echo "Error: Failed to read response" >&2; exit 1; }

# Validate HTTP_CODE is numeric before comparison
if ! [[ "$HTTP_CODE" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid HTTP response code: $HTTP_CODE" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "Error: API returned HTTP $HTTP_CODE" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Output Response
# -----------------------------------------------------------------------------

echo ""
echo "=== PEER CONSULTANT RESPONSE ==="
echo ""
echo "## Response"
echo ""

OUTPUT_TEXT=$(extract_response_text "$RESPONSE")

if [[ -z "$OUTPUT_TEXT" ]]; then
  echo "Warning: Empty response from API" >&2
  echo "Raw response:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

echo "$OUTPUT_TEXT"
