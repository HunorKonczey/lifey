import { describe, expect, it } from "vitest";
import sitemap from "./sitemap";
import { routing } from "@/i18n/routing";

describe("sitemap (65 §5.3)", () => {
  const entries = sitemap();
  const routeCount = Object.keys(routing.pathnames).length;

  it("lists every marketing route in both locales", () => {
    expect(entries).toHaveLength(routeCount * routing.locales.length);
  });

  it("every entry is an absolute lifey.hu URL", () => {
    for (const entry of entries) {
      expect(entry.url).toMatch(/^https:\/\/lifey\.hu\//);
    }
  });

  it("every entry carries alternates for both locales", () => {
    for (const entry of entries) {
      const languages = entry.alternates?.languages;
      expect(languages).toBeDefined();
      for (const locale of routing.locales) {
        expect(languages?.[locale]).toMatch(/^https:\/\/lifey\.hu\//);
      }
    }
  });

  it("the hu and en entries for the same route point at different localized paths", () => {
    // /for-trainers is hu:"/edzoknek" vs en:"/for-trainers" — a real
    // divergence, not the root "/" which is identical in both locales.
    const forTrainersUrls = entries
      .filter((e) => e.url.includes("edzoknek") || e.url.endsWith("/for-trainers"))
      .map((e) => e.url);
    expect(forTrainersUrls).toHaveLength(2);
    expect(new Set(forTrainersUrls).size).toBe(2);
  });

  it("no duplicate URLs", () => {
    const urls = entries.map((e) => e.url);
    expect(new Set(urls).size).toBe(urls.length);
  });
});
