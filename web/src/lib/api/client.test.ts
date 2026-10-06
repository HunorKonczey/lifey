import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, api, registerTokenRefresher, setAccessToken } from "./client";

/**
 * The 401 path of the API client. A request that finds its access token expired asks the registered
 * refresher for a new one; the refresher itself calls `POST /auth/refresh` through this same client.
 */

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

const fetchMock = vi.fn<typeof fetch>();

beforeEach(() => {
  vi.stubGlobal("fetch", fetchMock);
  fetchMock.mockReset();
  setAccessToken(null);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

/** Resolves with what the promise settles to, or "hung" if it has not settled in `ms`. */
function settle<T>(promise: Promise<T>, ms = 300): Promise<{ ok: T } | { error: unknown } | "hung"> {
  return Promise.race([
    promise.then((ok) => ({ ok }), (error) => ({ error })),
    new Promise<"hung">((resolve) => setTimeout(() => resolve("hung"), ms)),
  ]);
}

describe("401 handling", () => {
  it("retries the request once with the refreshed token", async () => {
    setAccessToken("expired");
    registerTokenRefresher(async () => "fresh");
    fetchMock.mockResolvedValueOnce(json(401, { message: "expired" })).mockResolvedValueOnce(json(200, { ok: true }));

    const result = await settle(api.get<{ ok: boolean }>("/weights"));

    expect(result).toEqual({ ok: { ok: true } });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    const retryHeaders = fetchMock.mock.calls[1][1]?.headers as Record<string, string>;
    expect(retryHeaders.Authorization).toBe("Bearer fresh");
  });

  it("gives up with a 401 when the refresh token itself is refused, instead of waiting on itself forever", async () => {
    setAccessToken("expired");
    // The real refresher (features/auth/store.ts) exchanges the stored refresh token through the same client.
    registerTokenRefresher(async () => {
      try {
        const response = await api.post<{ accessToken: string }>("/auth/refresh", { refreshToken: "revoked" });
        return response.accessToken;
      } catch {
        return null;
      }
    });
    fetchMock.mockImplementation(async (input) =>
      String(input).endsWith("/auth/refresh") ? json(401, { message: "revoked" }) : json(401, { message: "expired" }),
    );

    const result = await settle(api.get("/weights"));

    expect(result).not.toBe("hung");
    expect(result).toMatchObject({ error: expect.any(ApiError) });
    expect((result as { error: ApiError }).error.status).toBe(401);
  });

  it("does not try to refresh without an access token (bad credentials, not an expired session)", async () => {
    const refresher = vi.fn(async () => "fresh");
    registerTokenRefresher(refresher);
    fetchMock.mockResolvedValueOnce(json(401, { message: "bad credentials" }));

    const result = await settle(api.post("/auth/login", { email: "a@b.c", password: "x" }));

    expect(result).toMatchObject({ error: expect.any(ApiError) });
    expect(refresher).not.toHaveBeenCalled();
  });
});
