# me — Account Profile

Retrieve your X account profile data, metrics, and verification status.

## Usage

```
<base_directory>/x me [flags]
```

## Flags

| Flag | Description |
|------|-------------|
| *(none)* | Full profile with sensible defaults |
| `--fields <list>` | Only specific fields (comma-separated) |
| `--pinned-tweet` | Include pinned tweet data (expanded) |
| `--raw` | Full API response envelope (data + includes + errors) |

## Available Fields

`id`, `name`, `username`, `description`, `created_at`, `location`, `url`, `profile_image_url`, `protected`, `public_metrics`, `verified_type`, `pinned_tweet_id`, `most_recent_tweet_id`, `entities`, `withheld`

Default fields: `id`, `name`, `username`, `description`, `created_at`, `location`, `url`, `profile_image_url`, `protected`, `public_metrics`, `verified_type`

## Examples

```bash
# Full profile (default fields)
<base_directory>/x me

# Just username and metrics
<base_directory>/x me --fields username,public_metrics

# Include pinned tweet content
<base_directory>/x me --pinned-tweet

# Raw API response
<base_directory>/x me --raw
```

## Output

JSON to stdout.

**Default** — outputs the user object directly:

```json
{
  "id": "160409899...",
  "name": "Alberto",
  "username": "alberduris",
  "description": "...",
  "public_metrics": {
    "followers_count": 693,
    "following_count": 500,
    "tweet_count": 4584,
    "listed_count": 12
  },
  "verified_type": "blue",
  ...
}
```

**`--pinned-tweet` or `--raw`** — outputs full response including expansions:

```json
{
  "data": { ... },
  "includes": { "tweets": [ ... ] }
}
```
