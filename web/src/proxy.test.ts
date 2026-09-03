import { describe, expect, it } from "vitest";
import { unstable_doesMiddlewareMatch } from "next/experimental/testing/server";
import { NextRequest } from "next/server";
import proxy, { config } from "./proxy";
import { ATTRIBUTION_COOKIE } from "./lib/attribution";

/**
 * The matcher is correctness-critical (docs/landing_page/65 §D-W3): widening
 * it puts this proxy in front of every authenticated request. Every
 * authenticated route group and every framework-internal path gets an
 * explicit negative assertion here, not just a couple of examples.
 */
describe("proxy matcher", () => {
  it.each(["/", "/hu", "/en", "/hu/edzoknek", "/en/pricing", "/hu/jogi/aszf"])(
    "matches the marketing tree: %s",
    (url) => {
      expect(unstable_doesMiddlewareMatch({ config, url })).toBe(true);
    },
  );

  it.each([
    "/dashboard",
    "/nutrition",
    "/workouts",
    "/weight",
    "/water",
    "/steps",
    "/statistics",
    "/settings",
    "/onboarding",
    "/admin",
    "/admin/clients/1",
    "/admin/chat",
    "/superadmin/users",
    "/login",
    "/register",
    "/forgot-password",
    "/_next/static/chunk.js",
    "/_next/image?url=%2Ffoo.png",
    "/favicon.ico",
  ])("does not match the authenticated app or framework internals: %s", (url) => {
    expect(unstable_doesMiddlewareMatch({ config, url })).toBe(false);
  });
});

/**
 * First-touch attribution (docs/landing_page/65 D-W8) is written here rather
 * than only from `AttributionCapture.tsx`'s effect, so a visitor who bounces
 * before hydration is still attributed.
 */
describe("first-touch attribution cookie", () => {
  const run = (path: string, cookie?: string) =>
    proxy(
      new NextRequest(new URL(path, "http://localhost:3000"), {
        headers: cookie ? { cookie } : undefined,
      })
    );

  const attributionCookie = (response: Response) =>
    response.headers.getSetCookie().find((c) => c.startsWith(`${ATTRIBUTION_COOKIE}=`));

  it("writes an inbound utm campaign on the first response", () => {
    expect(attributionCookie(run("/hu?utm_source=newsletter&utm_campaign=spring"))).toContain(
      "lifey_attrib=utm_source%3Dnewsletter%26utm_campaign%3Dspring"
    );
  });

  it("writes the cookie on the locale redirect too, not just on the landed page", () => {
    const response = run("/?utm_source=newsletter");
    expect(response.status).toBe(307);
    expect(attributionCookie(response)).toContain("lifey_attrib=utm_source%3Dnewsletter");
  });

  it("falls back to this site's own ?src when there is no campaign", () => {
    expect(attributionCookie(run("/hu/arak?src=pricing-pro"))).toContain(
      "lifey_attrib=src%3Dpricing-pro"
    );
  });

  it("never overwrites an existing first touch", () => {
    const response = run("/hu/arak?src=pricing-pro", `${ATTRIBUTION_COOKIE}=utm_source%3Dnewsletter`);
    expect(attributionCookie(response)).toBeUndefined();
  });

  it("writes nothing when the visitor arrived with no attribution at all", () => {
    expect(attributionCookie(run("/hu"))).toBeUndefined();
  });

  it("leaves next-intl's own locale handling intact", () => {
    expect(run("/?utm_source=newsletter").headers.get("location")).toBe(
      "http://localhost:3000/hu?utm_source=newsletter"
    );
  });
});
