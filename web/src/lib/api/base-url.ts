import { env } from "@/lib/env";

/**
 * Where chat traffic goes (docs/chat/44-chat-service-extraction-plan.md §7.1).
 *
 * The chat runs as its own service, so the web has two origins to talk to. The
 * URL is resolved at **runtime** from `GET /api/v1/client-config` rather than
 * only from the build, for the same reason the mobile app does it: the answer
 * has to be changeable — and revertible — without shipping a client. On the web
 * a redeploy is fast, but "fast" during an incident is still a build, and the
 * two clients behaving differently would be its own problem.
 *
 * Resolution order:
 *   1. whatever `/client-config` last said,
 *   2. `NEXT_PUBLIC_CHAT_BASE_URL`, if the build set one,
 *   3. the main API's base URL — i.e. "the chat is served by the API".
 *
 * The last step is the one that matters: an unreachable config endpoint, or a
 * deployment that has not set the variable, degrades to the pre-split behaviour
 * instead of leaving the chat pointed at nothing.
 */
let resolvedChatBaseUrl: string | null = null;

export function chatBaseUrl(): string {
  return (
    resolvedChatBaseUrl || env.NEXT_PUBLIC_CHAT_BASE_URL || env.NEXT_PUBLIC_API_BASE_URL
  );
}

/** Empty or missing means "served by the main API" — not an error. */
export function setChatBaseUrl(url: string | null | undefined) {
  resolvedChatBaseUrl = url && url.trim() ? url.trim() : null;
}
