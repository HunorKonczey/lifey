import { chatBaseUrl } from "@/lib/api/base-url";
import { env } from "@/lib/env";

// Spring Data `Page<T>` as serialized by any GET .../{resource}?page=... endpoint
// migrated to the pageable+searchable pattern (see docs/05-backend-api.md — Foods
// is the first, other long lists follow the same shape).
export interface Page<T> {
  content: T[];
  totalElements: number;
  totalPages: number;
  number: number;
  size: number;
  last: boolean;
}

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }

  get isRetryable() {
    return this.status >= 500;
  }
}

type TokenRefresher = () => Promise<string | null>;

let accessToken: string | null = null;
let refreshPromise: Promise<string | null> | null = null;
let tokenRefresher: TokenRefresher | null = null;

export function setAccessToken(token: string | null) {
  accessToken = token;
}

export function getAccessToken() {
  return accessToken;
}

export function registerTokenRefresher(fn: TokenRefresher) {
  tokenRefresher = fn;
}

/**
 * Refresh the access token from outside the normal request path. The SSE
 * reader (lib/api/chat-stream.ts) can't go through `request()` — it consumes a
 * stream rather than a body — so it needs its own way to recover from a 401
 * instead of reconnecting forever with a token that has already expired.
 */
export async function refreshAccessToken(): Promise<string | null> {
  const token = await refreshOnce();
  setAccessToken(token);
  return token;
}

async function refreshOnce(): Promise<string | null> {
  if (refreshPromise) return refreshPromise;
  if (!tokenRefresher) return null;

  refreshPromise = tokenRefresher().finally(() => {
    refreshPromise = null;
  });
  return refreshPromise;
}

interface RequestConfig {
  retry?: boolean;
  /** "blob" for binary responses (e.g. the profile picture) — skips JSON parsing. */
  parseAs?: "json" | "blob";
  /**
   * Which service to call. Defaults to the main API; the chat lives elsewhere
   * (docs/chat/44-chat-service-extraction-plan.md §7.3). A function rather than
   * a string because the chat's URL is resolved at runtime and can change while
   * the tab is open.
   */
  baseUrl?: () => string;
}

async function request<T>(
  path: string,
  init: RequestInit = {},
  config: RequestConfig = {},
): Promise<T> {
  const { retry = true, parseAs = "json", baseUrl } = config;
  // FormData sets its own multipart boundary in the Content-Type header —
  // letting fetch do that means not setting the header ourselves at all.
  const isFormData = init.body instanceof FormData;
  const headers: Record<string, string> = {
    ...(isFormData ? {} : { "Content-Type": "application/json" }),
    // Sent on every request (including register/login/refresh) so the backend
    // can keep the user's stored UTC offset current — see the day-boundary
    // bug where the server's own zone was used instead of the user's.
    "X-Utc-Offset-Minutes": String(-new Date().getTimezoneOffset()),
    ...(init.headers as Record<string, string>),
  };

  if (accessToken) {
    headers["Authorization"] = `Bearer ${accessToken}`;
  }

  const origin = baseUrl ? baseUrl() : env.NEXT_PUBLIC_API_BASE_URL;
  const res = await fetch(`${origin}${path}`, {
    ...init,
    headers,
    credentials: "include",
  });

  // Only attempt refresh if we had an active token that may have expired.
  // A 401 without an active token means bad credentials, not an expired session.
  if (res.status === 401 && retry && accessToken) {
    const newToken = await refreshOnce();
    if (newToken) {
      setAccessToken(newToken);
      return request<T>(path, init, { retry: false, parseAs, baseUrl });
    }
    setAccessToken(null);
    throw new ApiError(401, "UNAUTHORIZED", "Session expired");
  }

  if (!res.ok) {
    let code = "UNKNOWN";
    let message = res.statusText;
    try {
      const body = await res.json();
      code = body.error ?? code;
      message = body.message ?? message;
    } catch {
      // non-JSON error body
    }
    throw new ApiError(res.status, code, message);
  }

  if (res.status === 204) return undefined as T;

  if (parseAs === "blob") return (await res.blob()) as unknown as T;

  // Some endpoints (e.g. forgot-password) return 200 with an empty body —
  // res.json() throws on empty input, so check for content first.
  const text = await res.text();
  if (!text) return undefined as T;
  return JSON.parse(text) as T;
}

/**
 * The same client, pointed at the chat service.
 *
 * Everything else is shared on purpose: one access token, one refresh path (to
 * the main API — the chat service only verifies tokens, it cannot issue one,
 * §5.3), and one error shape. Only the origin differs.
 */
function chatRequest<T>(path: string, init: RequestInit = {}, config: RequestConfig = {}) {
  return request<T>(path, init, { ...config, baseUrl: chatBaseUrl });
}

export const api = {
  get: <T>(path: string, init?: RequestInit) => request<T>(path, { method: "GET", ...init }),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "POST", body: JSON.stringify(body) }),
  put: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PUT", body: JSON.stringify(body) }),
  patch: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PATCH", body: JSON.stringify(body) }),
  delete: <T = void>(path: string) => request<T>(path, { method: "DELETE" }),
  /** Binary GET (e.g. the profile picture) — 404 still throws, callers decide how to treat it. */
  getBlob: (path: string) => request<Blob>(path, { method: "GET" }, { parseAs: "blob" }),
  /** PUT with a multipart body (e.g. a file upload) instead of JSON. */
  putForm: (path: string, formData: FormData) =>
    request<void>(path, { method: "PUT", body: formData }),
  /** POST with a multipart body, answered with JSON (e.g. sending a chat image). */
  postForm: <T>(path: string, formData: FormData) =>
    request<T>(path, { method: "POST", body: formData }),
};

/** Mirror of {@link api} for `/chat/**`. Same session, different host. */
export const chatClient = {
  get: <T>(path: string) => chatRequest<T>(path, { method: "GET" }),
  post: <T>(path: string, body?: unknown) =>
    chatRequest<T>(path, { method: "POST", body: JSON.stringify(body) }),
  put: <T>(path: string, body?: unknown) =>
    chatRequest<T>(path, { method: "PUT", body: JSON.stringify(body) }),
  delete: <T = void>(path: string) => chatRequest<T>(path, { method: "DELETE" }),
  getBlob: (path: string) => chatRequest<Blob>(path, { method: "GET" }, { parseAs: "blob" }),
  postForm: <T>(path: string, formData: FormData) =>
    chatRequest<T>(path, { method: "POST", body: formData }),
};
