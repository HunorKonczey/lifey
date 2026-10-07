import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, api, keepaliveDelete, keepalivePut, registerTokenRefresher, setAccessToken } from "./client";

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

describe("deferred writes (undo window)", () => {
  it("a delete sent on an expired token is refreshed and sent again, not reported as failed", async () => {
    setAccessToken("expired");
    registerTokenRefresher(async () => "fresh");
    fetchMock.mockResolvedValueOnce(json(401, { message: "expired" })).mockResolvedValueOnce(new Response(null, { status: 204 }));

    await expect(keepaliveDelete("/meals/5")).resolves.toBeUndefined();

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect((fetchMock.mock.calls[1][1]?.headers as Record<string, string>).Authorization).toBe("Bearer fresh");
    expect(fetchMock.mock.calls[1][1]?.keepalive).toBe(true);
  });

  it("an edit keeps its body when it is sent again", async () => {
    setAccessToken("expired");
    registerTokenRefresher(async () => "fresh");
    fetchMock.mockResolvedValueOnce(json(401, {})).mockResolvedValueOnce(json(200, {}));

    await keepalivePut("/meals/5", { entries: [] });

    expect(fetchMock.mock.calls[1][1]?.body).toBe(JSON.stringify({ entries: [] }));
  });

  it("still fails when the session cannot be refreshed", async () => {
    setAccessToken("expired");
    registerTokenRefresher(async () => null);
    fetchMock.mockResolvedValue(json(401, {}));

    await expect(keepaliveDelete("/meals/5")).rejects.toMatchObject({ status: 401 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("a normal failure is not retried", async () => {
    setAccessToken("fresh");
    fetchMock.mockResolvedValue(json(404, {}));

    await expect(keepaliveDelete("/meals/5")).rejects.toMatchObject({ status: 404 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});
