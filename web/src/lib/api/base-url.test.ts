import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { chatBaseUrl, setChatBaseUrl } from "./base-url";
import { api, chatClient, setAccessToken } from "./client";
import { env } from "@/lib/env";

/**
 * Which service each call goes to (docs/chat/44-chat-service-extraction-plan.md §7.3).
 *
 * <p>Worth its own test because the failure is silent in exactly the wrong way:
 * a chat call sent to the main API gets a plausible-looking 404, and a trainer
 * call sent to the chat service gets the same — so nothing crashes, the feature
 * just quietly stops working for whoever deployed it.
 */
describe("api base URLs", () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    setChatBaseUrl(null);
    setAccessToken(null);
    fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({}), { status: 200, headers: { "Content-Type": "application/json" } }),
    );
    vi.stubGlobal("fetch", fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    setChatBaseUrl(null);
  });

  const calledUrl = () => String(fetchMock.mock.calls[0][0]);

  it("falls back to the main API when no chat service is configured", () => {
    // The pre-split state and the rollback. Empty must never mean "broken".
    expect(chatBaseUrl()).toBe(env.NEXT_PUBLIC_API_BASE_URL);
  });

  it("uses the runtime answer once client-config has replied", () => {
    setChatBaseUrl("https://lifey-chat.example.com/api/v1");

    expect(chatBaseUrl()).toBe("https://lifey-chat.example.com/api/v1");
  });

  it("treats blank and whitespace as 'not configured'", () => {
    setChatBaseUrl("   ");

    expect(chatBaseUrl()).toBe(env.NEXT_PUBLIC_API_BASE_URL);
  });

  it("sends chat calls to the chat service", async () => {
    setChatBaseUrl("https://lifey-chat.example.com/api/v1");

    await chatClient.get("/chat/conversations");

    expect(calledUrl()).toBe("https://lifey-chat.example.com/api/v1/chat/conversations");
  });

  it("keeps everything else on the main API", async () => {
    // /trainer/clients is the API's, even though the chat UI is what calls it.
    setChatBaseUrl("https://lifey-chat.example.com/api/v1");

    await api.get("/trainer/clients");

    expect(calledUrl()).toBe(`${env.NEXT_PUBLIC_API_BASE_URL}/trainer/clients`);
  });

  it("retries a chat call against the chat service, not the main API", async () => {
    // The retry path used to hardcode the origin; a 401 would then send the
    // retry to the wrong host and look like a broken session.
    setChatBaseUrl("https://lifey-chat.example.com/api/v1");
    setAccessToken("expired-token");
    fetchMock
      .mockResolvedValueOnce(new Response("", { status: 401 }))
      .mockResolvedValueOnce(
        new Response(JSON.stringify({}), { status: 200, headers: { "Content-Type": "application/json" } }),
      );
    const { registerTokenRefresher } = await import("./client");
    registerTokenRefresher(async () => "fresh-token");

    await chatClient.get("/chat/conversations");

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(String(fetchMock.mock.calls[1][0])).toBe(
      "https://lifey-chat.example.com/api/v1/chat/conversations",
    );
  });
});
