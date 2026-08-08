import { chatBaseUrl } from "@/lib/api/base-url";
import { getAccessToken, refreshAccessToken } from "@/lib/api/client";

/**
 * SSE reader for the chat stream (docs/chat/40-trainer-chat-plan.md §6.2).
 *
 * The native `EventSource` is unusable here: it cannot set an `Authorization`
 * header, and the two alternatives — a token in the query string, or a
 * short-lived ticket endpoint — cost either a token in logs and referrers or an
 * extra endpoint plus extra state. A fetch-based reader is ~100 lines, sets
 * whatever headers it likes, and aborts cleanly.
 */

export interface ChatStreamFrame {
  /** `event:` — "message", "read", "deleted" or "resync". */
  name: string;
  /** `id:`, present only on message frames, which is what makes it the cursor. */
  id: string | null;
  /** Parsed `data:` payload, or null when it wasn't JSON. */
  data: unknown;
}

export interface ChatStreamOptions {
  onFrame: (frame: ChatStreamFrame) => void;
  /** Reported on every connect/disconnect so the UI can fall back to polling. */
  onConnectionChange?: (connected: boolean) => void;
}

/** Reconnect delays in ms; the last one repeats for as long as it keeps failing. */
const BACKOFF_MS = [1_000, 2_000, 5_000, 15_000];

/**
 * Opens the stream and keeps it open, reconnecting with the newest message id
 * it has seen. Returns a function that closes it for good.
 */
export function connectChatStream({ onFrame, onConnectionChange }: ChatStreamOptions): () => void {
  const controller = new AbortController();
  let lastEventId: string | null = null;
  let attempt = 0;
  let stopped = false;
  let retryTimer: ReturnType<typeof setTimeout> | null = null;

  const run = async () => {
    while (!stopped) {
      try {
        const refreshed = await readStream();
        // A clean end is the server's stream-timeout, not a failure: reconnect
        // immediately rather than sitting out a backoff for a healthy stream.
        attempt = refreshed ? 0 : attempt;
      } catch {
        // Every failure is the same failure here — a dead connection — and the
        // answer is always to back off and try again, so the cause is not read.
        if (stopped || controller.signal.aborted) return;
        attempt += 1;
        onConnectionChange?.(false);
        await sleep(BACKOFF_MS[Math.min(attempt - 1, BACKOFF_MS.length - 1)]);
      }
    }
  };

  /** @returns true if the stream ended normally (server timeout / close). */
  const readStream = async (): Promise<boolean> => {
    // The chat service's origin, resolved at runtime (§7.1) — read on every
      // attempt, so a reconnect after a base-URL change lands on the new host.
      const response = await fetch(`${chatBaseUrl()}/chat/stream`, {
      method: "GET",
      signal: controller.signal,
      credentials: "include",
      headers: {
        Accept: "text/event-stream",
        ...(getAccessToken() ? { Authorization: `Bearer ${getAccessToken()}` } : {}),
        ...(lastEventId ? { "Last-Event-ID": lastEventId } : {}),
      },
    });

    if (response.status === 401) {
      // Reconnecting with the same dead token would just loop; one refresh
      // here puts the next attempt back on a valid session.
      await refreshAccessToken();
      throw new Error("chat stream unauthorized");
    }
    if (!response.ok || !response.body) {
      throw new Error(`chat stream failed: ${response.status}`);
    }

    attempt = 0;
    onConnectionChange?.(true);

    const reader = response.body.pipeThrough(new TextDecoderStream()).getReader();
    let buffer = "";
    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += value;

        // Frames are separated by a blank line; anything after the last one is
        // a partial frame and stays in the buffer for the next chunk.
        let separator = buffer.indexOf("\n\n");
        while (separator !== -1) {
          const raw = buffer.slice(0, separator);
          buffer = buffer.slice(separator + 2);
          const frame = parseFrame(raw);
          if (frame) {
            if (frame.id) lastEventId = frame.id;
            onFrame(frame);
          }
          separator = buffer.indexOf("\n\n");
        }
      }
    } finally {
      reader.cancel().catch(() => {
        /* already closed */
      });
      onConnectionChange?.(false);
    }
    return true;
  };

  const sleep = (ms: number) =>
    new Promise<void>((resolve) => {
      // Jitter so a backend restart doesn't bring every client back at once.
      retryTimer = setTimeout(resolve, ms + Math.random() * 500);
    });

  void run();

  return () => {
    stopped = true;
    if (retryTimer) clearTimeout(retryTimer);
    controller.abort();
  };
}

/**
 * One SSE frame: `id:` / `event:` / one or more `data:` lines.
 * Exported for its own test — the wire format is easy to get subtly wrong and
 * hard to notice, since a mis-parsed frame just silently does nothing.
 */
export function parseFrame(raw: string): ChatStreamFrame | null {
  let name = "message";
  let id: string | null = null;
  const dataLines: string[] = [];

  for (const line of raw.split("\n")) {
    // Comment line — the server's heartbeat arrives as one, and it exists to
    // keep proxies from closing the connection, not to be handled.
    if (line.startsWith(":")) continue;
    const colon = line.indexOf(":");
    const field = colon === -1 ? line : line.slice(0, colon);
    const value = colon === -1 ? "" : line.slice(colon + 1).replace(/^ /, "");
    if (field === "event") name = value;
    else if (field === "id") id = value;
    else if (field === "data") dataLines.push(value);
  }

  if (dataLines.length === 0) return null;
  try {
    return { name, id, data: JSON.parse(dataLines.join("\n")) };
  } catch {
    return { name, id, data: null };
  }
}
