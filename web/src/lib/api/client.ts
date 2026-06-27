import { env } from "@/lib/env";

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

async function refreshOnce(): Promise<string | null> {
  if (refreshPromise) return refreshPromise;
  if (!tokenRefresher) return null;

  refreshPromise = tokenRefresher().finally(() => {
    refreshPromise = null;
  });
  return refreshPromise;
}

async function request<T>(
  path: string,
  init: RequestInit = {},
  retry = true,
): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(init.headers as Record<string, string>),
  };

  if (accessToken) {
    headers["Authorization"] = `Bearer ${accessToken}`;
  }

  const res = await fetch(`${env.NEXT_PUBLIC_API_BASE_URL}${path}`, {
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
      return request<T>(path, init, false);
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

  return res.json() as Promise<T>;
}

export const api = {
  get: <T>(path: string) => request<T>(path, { method: "GET" }),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "POST", body: JSON.stringify(body) }),
  put: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PUT", body: JSON.stringify(body) }),
  delete: <T = void>(path: string) => request<T>(path, { method: "DELETE" }),
};
