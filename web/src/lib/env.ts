import { z } from "zod";

const envSchema = z.object({
  NEXT_PUBLIC_API_BASE_URL: z
    .string()
    .url()
    .default("http://localhost:8080/api/v1"),
  // Web OAuth client ID from the Google Cloud Console. Must be one of the IDs
  // listed in the backend's OAUTH_GOOGLE_CLIENT_IDS. Empty disables the button.
  NEXT_PUBLIC_GOOGLE_CLIENT_ID: z.string().optional().default(""),
});

export const env = envSchema.parse({
  NEXT_PUBLIC_API_BASE_URL: process.env.NEXT_PUBLIC_API_BASE_URL,
  NEXT_PUBLIC_GOOGLE_CLIENT_ID: process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID,
});
