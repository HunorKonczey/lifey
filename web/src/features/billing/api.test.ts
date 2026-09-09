import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { setAccessToken } from "@/lib/api/client";
import { env } from "@/lib/env";
import { billingApi } from "./api";

describe("billingApi", () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  const jsonResponse = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

  beforeEach(() => {
    setAccessToken("a-token");
    fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    setAccessToken(null);
  });

  it("entitlements() calls GET /me/entitlements", async () => {
    fetchMock.mockResolvedValue(jsonResponse({ tier: "FREE" }));

    await billingApi.entitlements();

    expect(String(fetchMock.mock.calls[0][0])).toBe(`${env.NEXT_PUBLIC_API_BASE_URL}/me/entitlements`);
    expect((fetchMock.mock.calls[0][1] as RequestInit).method).toBe("GET");
  });

  it("checkoutSession() posts the plan and interval, and returns the redirect URL", async () => {
    fetchMock.mockResolvedValue(jsonResponse({ url: "https://checkout.stripe.com/x" }));

    const result = await billingApi.checkoutSession({ plan: "PRO", interval: "YEARLY" });

    expect(String(fetchMock.mock.calls[0][0])).toBe(`${env.NEXT_PUBLIC_API_BASE_URL}/billing/checkout-session`);
    const init = fetchMock.mock.calls[0][1] as RequestInit;
    expect(init.method).toBe("POST");
    expect(JSON.parse(init.body as string)).toEqual({ plan: "PRO", interval: "YEARLY" });
    expect(result.url).toBe("https://checkout.stripe.com/x");
  });

  it("portalSession() posts with no body, and returns the redirect URL", async () => {
    fetchMock.mockResolvedValue(jsonResponse({ url: "https://billing.stripe.com/p/x" }));

    const result = await billingApi.portalSession();

    expect(String(fetchMock.mock.calls[0][0])).toBe(`${env.NEXT_PUBLIC_API_BASE_URL}/billing/portal-session`);
    expect((fetchMock.mock.calls[0][1] as RequestInit).method).toBe("POST");
    expect(result.url).toBe("https://billing.stripe.com/p/x");
  });
});
