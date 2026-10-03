// Plain validation, deliberately not zod: this module is imported by the API
// client, which the marketing header's auth island pulls into every marketing
// page's first-load bundle — and zod alone was ~64 KB gzipped of it
// (docs/landing_page/72 W7 / F6). Three string variables do not need a schema
// library. The behaviour is the schema's: a missing value takes its default,
// a present-but-malformed API URL throws at import time.

const DEFAULT_API_BASE_URL = "http://localhost:8080/api/v1";

function apiBaseUrl(value: string | undefined): string {
  const url = value ?? DEFAULT_API_BASE_URL;
  try {
    new URL(url);
  } catch {
    throw new Error(`Invalid environment variable NEXT_PUBLIC_API_BASE_URL: "${url}" is not a URL`);
  }
  return url;
}

export const env = {
  NEXT_PUBLIC_API_BASE_URL: apiBaseUrl(process.env.NEXT_PUBLIC_API_BASE_URL),
  // Web OAuth client ID from the Google Cloud Console. Must be one of the IDs
  // listed in the backend's OAUTH_GOOGLE_CLIENT_IDS. Empty disables the button.
  NEXT_PUBLIC_GOOGLE_CLIENT_ID: process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID ?? "",
  // Build-time fallback for the chat service's base URL. The runtime answer
  // from GET /client-config wins; this only covers the window before that
  // resolves, and an empty value means "the chat is served by the API".
  // See lib/api/base-url.ts and docs/chat/44-chat-service-extraction-plan.md §7.1.
  NEXT_PUBLIC_CHAT_BASE_URL: process.env.NEXT_PUBLIC_CHAT_BASE_URL ?? "",
};
