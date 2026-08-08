import { z } from "zod";

const envSchema = z.object({
  NEXT_PUBLIC_API_BASE_URL: z
    .string()
    .url()
    .default("http://localhost:8080/api/v1"),
  // Web OAuth client ID from the Google Cloud Console. Must be one of the IDs
  // listed in the backend's OAUTH_GOOGLE_CLIENT_IDS. Empty disables the button.
  NEXT_PUBLIC_GOOGLE_CLIENT_ID: z.string().optional().default(""),
  // Build-time fallback for the chat service's base URL. The runtime answer
  // from GET /client-config wins; this only covers the window before that
  // resolves, and an empty value means "the chat is served by the API".
  // See lib/api/base-url.ts and docs/chat/44-chat-service-extraction-plan.md §7.1.
  NEXT_PUBLIC_CHAT_BASE_URL: z.string().optional().default(""),
});

export const env = envSchema.parse({
  NEXT_PUBLIC_API_BASE_URL: process.env.NEXT_PUBLIC_API_BASE_URL,
  NEXT_PUBLIC_GOOGLE_CLIENT_ID: process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID,
  NEXT_PUBLIC_CHAT_BASE_URL: process.env.NEXT_PUBLIC_CHAT_BASE_URL,
});
