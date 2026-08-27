import { describe, expect, it } from "vitest";
import { unstable_doesMiddlewareMatch } from "next/experimental/testing/server";
import { config } from "./proxy";

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
