import { describe, expect, it } from "vitest";
import robots from "./robots";

describe("robots (65 §5.3)", () => {
  const result = robots();
  const rules = Array.isArray(result.rules) ? result.rules : [result.rules];
  const disallow = rules.flatMap((r) => (Array.isArray(r.disallow) ? r.disallow : r.disallow ? [r.disallow] : []));

  it("disallows the four authenticated trees the doc names explicitly", () => {
    for (const path of ["/dashboard", "/admin", "/superadmin", "/onboarding"]) {
      expect(disallow).toContain(path);
    }
  });

  it("also disallows the rest of the authenticated (app) surface, not just the four named examples", () => {
    for (const path of ["/nutrition", "/workouts", "/statistics", "/steps", "/water", "/weight", "/settings"]) {
      expect(disallow).toContain(path);
    }
  });

  it("does not disallow the public auth entry points", () => {
    for (const path of ["/login", "/register", "/forgot-password"]) {
      expect(disallow).not.toContain(path);
    }
  });

  it("allows the marketing tree", () => {
    expect(rules.some((r) => r.allow === "/" || (Array.isArray(r.allow) && r.allow.includes("/")))).toBe(true);
  });

  it("points at the real sitemap", () => {
    expect(result.sitemap).toBe("https://lifey.hu/sitemap.xml");
  });
});
