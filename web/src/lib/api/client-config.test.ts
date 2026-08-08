import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { chatBaseUrl, setChatBaseUrl } from "./base-url";
import { setAccessToken } from "./client";
import { loadClientConfig } from "./client-config";
import { env } from "@/lib/env";

/**
 * `/client-config` is authenticated, and the whole chat split depends on it
 * being answered (docs/chat/44-chat-service-extraction-plan.md §7.1).
 *
 * <p>Worth its own test because the original bug was invisible from the UI: the
 * call went out without an `Authorization` header, came back 401, and the chat
 * quietly kept pointing at the main API — which answers 404 for `/chat/**`
 * since the split. Nothing crashed; the chat just said "couldn't load".
 */
describe("loadClientConfig", () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  const jsonResponse = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    });

  beforeEach(() => {
    setChatBaseUrl(null);
    setAccessToken(null);
    fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    setChatBaseUrl(null);
    setAccessToken(null);
  });

  const headersOf = (call: number) =>
    (fetchMock.mock.calls[call][1] as RequestInit).headers as Record<string, string>;

  it("sends the access token, so the API can answer at all", async () => {
    setAccessToken("a-token");
    fetchMock.mockResolvedValue(
      jsonResponse({ chatBaseUrl: "https://lifey-chat.example.com/api/v1", configTtlSeconds: 300 }),
    );

    await loadClientConfig();

    expect(String(fetchMock.mock.calls[0][0])).toBe(`${env.NEXT_PUBLIC_API_BASE_URL}/client-config`);
    expect(headersOf(0)["Authorization"]).toBe("Bearer a-token");
  });

  it("points the chat at the service the API names", async () => {
    setAccessToken("a-token");
    fetchMock.mockResolvedValue(
      jsonResponse({ chatBaseUrl: "https://lifey-chat.example.com/api/v1", configTtlSeconds: 300 }),
    );

    await loadClientConfig();

    expect(chatBaseUrl()).toBe("https://lifey-chat.example.com/api/v1");
  });

  it("falls back to the main API when the call fails, instead of throwing", async () => {
    // The pre-login call, a 401, a service that is down — none of them may stop
    // the app loading, and none may leave the chat pointed at nothing.
    fetchMock.mockResolvedValue(new Response("", { status: 401 }));

    await expect(loadClientConfig()).resolves.toBeUndefined();
    expect(chatBaseUrl()).toBe(env.NEXT_PUBLIC_API_BASE_URL);
  });

  it("treats an empty answer as 'the API serves the chat'", async () => {
    // The rollback: emptying CHAT_PUBLIC_BASE_URL on lifey-api must send the
    // chat back to the main API without a client release.
    setAccessToken("a-token");
    setChatBaseUrl("https://lifey-chat.example.com/api/v1");
    fetchMock.mockResolvedValue(jsonResponse({ chatBaseUrl: "", configTtlSeconds: 300 }));

    await loadClientConfig();

    expect(chatBaseUrl()).toBe(env.NEXT_PUBLIC_API_BASE_URL);
  });
});
