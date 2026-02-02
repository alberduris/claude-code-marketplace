import type { Client } from "@xdevplatform/xdk";

const DEFAULT_FIELDS = [
  "created_at",
  "description",
  "id",
  "location",
  "name",
  "profile_image_url",
  "protected",
  "public_metrics",
  "url",
  "username",
  "verified_type",
];

interface Flags {
  fields: string[];
  pinnedTweet: boolean;
  raw: boolean;
}

function parseFlags(args: string[]): Flags {
  const flags: Flags = {
    fields: DEFAULT_FIELDS,
    pinnedTweet: false,
    raw: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--fields") {
      const value = args[++i];
      if (!value) throw new Error("--fields requires a comma-separated list");
      flags.fields = value.split(",").map((f) => f.trim());
    } else if (arg === "--pinned-tweet") {
      flags.pinnedTweet = true;
    } else if (arg === "--raw") {
      flags.raw = true;
    } else {
      throw new Error(`Unknown flag: ${arg}`);
    }
  }

  return flags;
}

export async function me(client: Client, args: string[]): Promise<void> {
  const flags = parseFlags(args);

  const options: Record<string, unknown> = {
    userFields: flags.fields,
  };

  if (flags.pinnedTweet) {
    options.expansions = ["pinned_tweet_id"];
    options.tweetFields = ["created_at", "text", "public_metrics"];
  }

  const response = await client.users.getMe(options);

  if (flags.raw || flags.pinnedTweet) {
    console.log(JSON.stringify(response, null, 2));
  } else {
    console.log(JSON.stringify(response.data, null, 2));
  }
}
