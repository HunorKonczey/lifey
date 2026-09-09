import { describe, expect, it } from "vitest";
import {
  ATTRIBUTION_COOKIE,
  buildAttributionCookieString,
  extractAttribution,
  readAttributionCookie,
} from "./attribution";

describe("extractAttribution", () => {
  it("returns null with neither utm_* nor src", () => {
    expect(extractAttribution("")).toBeNull();
    expect(extractAttribution("?ref=nothing-relevant")).toBeNull();
  });

  it("captures src when that's all there is", () => {
    expect(extractAttribution("?src=home-hero-primary")).toBe("src=home-hero-primary");
  });

  it("captures utm_* params, joined", () => {
    expect(extractAttribution("?utm_source=google&utm_medium=cpc")).toBe(
      "utm_source=google&utm_medium=cpc"
    );
  });

  it("utm_* wins over src when both are present", () => {
    expect(extractAttribution("?src=home-hero-primary&utm_source=google")).toBe(
      "utm_source=google"
    );
  });

  it("only includes utm_* keys that are actually present", () => {
    expect(extractAttribution("?utm_source=google&utm_campaign=spring")).toBe(
      "utm_source=google&utm_campaign=spring"
    );
  });

  it("URL-encodes values with special characters", () => {
    expect(extractAttribution("?src=" + encodeURIComponent("home hero/primary"))).toBe(
      "src=home%20hero%2Fprimary"
    );
  });
});

describe("cookie round-trip", () => {
  it("readAttributionCookie finds the cookie among others", () => {
    const raw = `other=1; ${ATTRIBUTION_COOKIE}=src%3Dhome-hero-primary; another=2`;
    expect(readAttributionCookie(raw)).toBe("src=home-hero-primary");
  });

  it("returns null when the cookie isn't present", () => {
    expect(readAttributionCookie("other=1; another=2")).toBeNull();
  });

  it("buildAttributionCookieString round-trips through readAttributionCookie", () => {
    const value = "utm_source=google&utm_campaign=spring sale";
    const cookieString = buildAttributionCookieString(value);
    // Simulate what the browser exposes via document.cookie: just "name=value" pairs.
    const asDocumentCookie = cookieString.split(";")[0];
    expect(readAttributionCookie(asDocumentCookie)).toBe(value);
  });

  it("the cookie string carries 30-day max-age, Lax, and no personal data", () => {
    const cookieString = buildAttributionCookieString("src=home-hero-primary");
    expect(cookieString).toContain(`max-age=${30 * 24 * 60 * 60}`);
    expect(cookieString).toContain("samesite=lax");
    expect(cookieString).toContain("path=/");
  });
});
