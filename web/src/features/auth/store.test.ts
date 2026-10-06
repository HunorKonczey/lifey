import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { setAccessToken } from "@/lib/api/client";
import { useSessionStore } from "./store";

/**
 * Exchanging the stored refresh token. It is single-use and lives in localStorage, so every tab of the app
 * shares it — the two things that must never happen are signing the user out because *another tab* spent the
 * token a moment earlier, and signing them out because the server was briefly unreachable.
 */

const RT_KEY = "lifey-rt";

function jwt(userId: number): string {
  const payload = Buffer.from(JSON.stringify({ sub: String(userId), email: "a@example.com", roles: [] })).toString(
    "base64url",
  );
  return `h.${payload}.s`;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

const pair = (userId: number, refreshToken: string) => json(200, { accessToken: jwt(userId), refreshToken, expiresIn: 900 });

const fetchMock = vi.fn<typeof fetch>();
let storage: Map<string, string>;

function sentRefreshToken(call: number): string {
  const init = fetchMock.mock.calls[call][1] as RequestInit;
  return (JSON.parse(String(init.body)) as { refreshToken: string }).refreshToken;
}

beforeEach(() => {
  storage = new Map();
  vi.stubGlobal("localStorage", {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => void storage.set(key, value),
    removeItem: (key: string) => void storage.delete(key),
  });
  vi.stubGlobal("fetch", fetchMock);
  fetchMock.mockReset();
  setAccessToken(null);
  useSessionStore.setState({ user: null, isLoading: true, initFailed: false });
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("initialize", () => {
  it("signs in with the stored refresh token and stores the rotated one", async () => {
    storage.set(RT_KEY, "T1");
    fetchMock.mockResolvedValueOnce(pair(7, "T2"));

    await useSessionStore.getState().initialize();

    expect(useSessionStore.getState().user?.id).toBe(7);
    expect(storage.get(RT_KEY)).toBe("T2");
  });

  it("is signed out, with the token cleared, when the server refuses the token", async () => {
    storage.set(RT_KEY, "T1");
    fetchMock.mockResolvedValueOnce(json(401, { message: "revoked" }));

    await useSessionStore.getState().initialize();

    expect(useSessionStore.getState().user).toBeNull();
    expect(useSessionStore.getState().initFailed).toBe(true);
    expect(storage.has(RT_KEY)).toBe(false);
  });

  it("keeps the refresh token when the server cannot be reached, so the next load still signs in", async () => {
    storage.set(RT_KEY, "T1");
    fetchMock.mockRejectedValueOnce(new TypeError("Failed to fetch"));

    await useSessionStore.getState().initialize();

    expect(useSessionStore.getState().user).toBeNull();
    expect(storage.get(RT_KEY)).toBe("T1");
  });

  it("keeps the refresh token through a 502 from the gateway while the API restarts", async () => {
    storage.set(RT_KEY, "T1");
    fetchMock.mockResolvedValueOnce(json(502, { message: "bad gateway" }));

    await useSessionStore.getState().initialize();

    expect(storage.get(RT_KEY)).toBe("T1");
  });

  it("tries the newer token when another tab rotated it while this one waited for the answer", async () => {
    storage.set(RT_KEY, "T1");
    fetchMock
      .mockImplementationOnce(async () => {
        // The other tab's exchange lands first: it spent T1 and stored T2.
        storage.set(RT_KEY, "T2");
        return json(401, { message: "revoked" });
      })
      .mockResolvedValueOnce(pair(7, "T3"));

    await useSessionStore.getState().initialize();

    expect(sentRefreshToken(1)).toBe("T2");
    expect(useSessionStore.getState().user?.id).toBe(7);
    expect(storage.get(RT_KEY)).toBe("T3");
  });

  it("does not delete a newer token that another tab stored while this one was refused", async () => {
    storage.set(RT_KEY, "T1");
    fetchMock
      .mockImplementationOnce(async () => {
        storage.set(RT_KEY, "T2");
        return json(401, { message: "revoked" });
      })
      .mockResolvedValueOnce(json(401, { message: "revoked" }));

    await useSessionStore.getState().initialize();

    // T2 was refused as well, and it was the stored one: that one is now cleared. What must never happen is
    // clearing T2 *without trying it* just because T1 was refused.
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(sentRefreshToken(1)).toBe("T2");
  });

  it("spends the token once when a page load and a role refresh run together", async () => {
    storage.set(RT_KEY, "T1");
    fetchMock.mockImplementation(async () => pair(7, "T2"));

    await Promise.all([useSessionStore.getState().initialize(), useSessionStore.getState().refreshUser()]);

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});

describe("logout", () => {
  it("tells the server which refresh token to revoke, and clears it locally", async () => {
    storage.set(RT_KEY, "T1");
    fetchMock.mockResolvedValueOnce(new Response(null, { status: 204 }));

    await useSessionStore.getState().logout();

    expect(String(fetchMock.mock.calls[0][0])).toMatch(/\/auth\/logout$/);
    expect(sentRefreshToken(0)).toBe("T1");
    expect(storage.has(RT_KEY)).toBe(false);
    expect(useSessionStore.getState().user).toBeNull();
  });

  it("signs out locally even when the server cannot be reached", async () => {
    storage.set(RT_KEY, "T1");
    fetchMock.mockRejectedValueOnce(new TypeError("Failed to fetch"));

    await useSessionStore.getState().logout();

    expect(storage.has(RT_KEY)).toBe(false);
    expect(useSessionStore.getState().user).toBeNull();
  });
});

describe("logoutAll", () => {
  it("asks the server while the access token is still there, then signs out locally", async () => {
    storage.set(RT_KEY, "T1");
    setAccessToken("A1");
    fetchMock.mockResolvedValueOnce(new Response(null, { status: 204 }));

    await useSessionStore.getState().logoutAll();

    expect(String(fetchMock.mock.calls[0][0])).toMatch(/auth\/logout-all$/);
    expect((fetchMock.mock.calls[0][1]?.headers as Record<string, string>).Authorization).toBe("Bearer A1");
    expect(storage.has(RT_KEY)).toBe(false);
    expect(useSessionStore.getState().user).toBeNull();
  });

  it("signs out locally even when the server cannot be reached", async () => {
    storage.set(RT_KEY, "T1");
    setAccessToken("A1");
    fetchMock.mockRejectedValueOnce(new TypeError("Failed to fetch"));

    await useSessionStore.getState().logoutAll();

    expect(storage.has(RT_KEY)).toBe(false);
    expect(useSessionStore.getState().user).toBeNull();
  });
});
