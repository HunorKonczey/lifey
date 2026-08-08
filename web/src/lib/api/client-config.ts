import { setChatBaseUrl } from "@/lib/api/base-url";
import { api } from "@/lib/api/client";

interface ClientConfigResponse {
  chatBaseUrl: string;
  configTtlSeconds: number;
}

const CACHE_KEY = "lifey.clientConfig.chatBaseUrl";

/**
 * Asks the API where the chat lives, and remembers the answer
 * (docs/chat/44-chat-service-extraction-plan.md §7.1).
 *
 * <p>Goes through {@link api} rather than a bare `fetch` because
 * `/client-config` is **authenticated**: a raw call carries no `Authorization`
 * header, gets a 401, and silently leaves the chat pointed at the main API —
 * which since the split answers 404. That is exactly the failure this endpoint
 * exists to prevent, and it is invisible unless you read the network tab.
 *
 * <p>Which is also why the caller re-runs this once a session exists
 * (`lib/providers.tsx`): the first attempt happens on page load, before anyone
 * has signed in, and is expected to fail.
 *
 * <p>Still **failure-safe**: a 401, a network error, a service that is down —
 * all of them leave the previously cached value in place, and if there is none,
 * `chatBaseUrl()` falls back to the main API. The worst outcome is chat
 * requests hitting an origin that answers 404, never an app that will not load.
 *
 * <p>Cached in `localStorage` so a reload does not spend a round trip before the
 * chat can render, and so a cold start with the API briefly unreachable still
 * knows where to go. It is neither a secret nor user data.
 */
export async function loadClientConfig(): Promise<void> {
  // Seed synchronously from the last known answer, so the first chat request in
  // this tab does not race the fetch below.
  const cached = readCache();
  if (cached !== null) setChatBaseUrl(cached);

  try {
    const config = await api.get<ClientConfigResponse>("/client-config");
    setChatBaseUrl(config.chatBaseUrl);
    writeCache(config.chatBaseUrl ?? "");
  } catch {
    // Keep whatever was cached. See the note above: this must not throw.
  }
}

function readCache(): string | null {
  try {
    return window.localStorage.getItem(CACHE_KEY);
  } catch {
    // Private mode, storage disabled — not a reason to fail.
    return null;
  }
}

function writeCache(value: string) {
  try {
    window.localStorage.setItem(CACHE_KEY, value);
  } catch {
    // As above.
  }
}
