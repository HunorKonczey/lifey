import { test, expect, type Page } from "@playwright/test";

/**
 * The JSON-LD on the four marketing pages that carry it (docs/landing_page/72 W9, LIF-119), checked against what Google's
 * Rich Results Test asks of each type: parseable, an absolute `url`, a `name` and `description` in the page's own
 * language, offers with a human name, a numeric price and a currency, and - for the FAQ - one `Question` per visible
 * question. The Rich Results Test itself needs a public URL; this runs on every PR so a regression is caught before there is
 * one to point it at.
 */

type Node = Record<string, unknown>;

async function jsonLd(page: Page, path: string): Promise<Node[]> {
  await page.goto(path);
  const raw = await page.locator('script[type="application/ld+json"]').allTextContents();
  expect(raw, `${path} has exactly one JSON-LD block`).toHaveLength(1);
  const parsed = JSON.parse(raw[0]) as Node;
  expect(parsed["@context"]).toBe("https://schema.org");
  return Array.isArray(parsed["@graph"]) ? (parsed["@graph"] as Node[]) : [parsed];
}

function offersOf(node: Node): Node[] {
  return node.offers as Node[];
}

function expectAbsoluteUrl(value: unknown) {
  expect(typeof value === "string" && /^https:\/\/lifey\.hu\//.test(value) || value === "https://lifey.hu").toBe(true);
}

const LOCALES = [
  { locale: "hu", home: "/hu", pricing: "/hu/arak", faq: "/hu/gyik", app: "/hu/app", perMonth: "/ hó", planNames: ["Starter", "Pro", "Studio"] },
  { locale: "en", home: "/en", pricing: "/en/pricing", faq: "/en/faq", app: "/en/app", perMonth: "/ mo", planNames: ["Starter", "Pro", "Studio"] },
];

for (const l of LOCALES) {
  test.describe(`structured data (${l.locale})`, () => {
    test("home: Organization and WebSite", async ({ page }) => {
      const nodes = await jsonLd(page, l.home);
      const types = nodes.map((n) => n["@type"]);
      expect(types).toEqual(["Organization", "WebSite"]);
      for (const n of nodes) {
        expect(n.name).toBe("Lifey");
        expectAbsoluteUrl(n.url);
      }
    });

    test("pricing: a Product whose offers carry the plan names, prices and currency", async ({ page }) => {
      const [product] = await jsonLd(page, l.pricing);
      expect(product["@type"]).toBe("Product");
      expect(String(product.name)).toMatch(/^Lifey/);
      expect(String(product.description).length).toBeGreaterThan(20);
      expectAbsoluteUrl(product.url);

      const offers = offersOf(product);
      expect(offers.map((o) => o.name)).toEqual(l.planNames);
      for (const o of offers) {
        expect(o["@type"]).toBe("Offer");
        expect(o.price).toMatch(/^\d+$/);
        expect(o.priceCurrency).toBe("HUF");
        expect(o.availability).toBe("https://schema.org/InStock");
        expectAbsoluteUrl(o.url);
      }
    });

    test("pricing: the offers' prices are the prices the page shows", async ({ page }) => {
      const [product] = await jsonLd(page, l.pricing);
      const body = (await page.locator("main").innerText()).replace(/\s/g, "");
      for (const o of offersOf(product)) {
        expect(body, `${o.name} ${o.price}`).toContain(`${o.price}Ft`);
      }
    });

    test("app: a SoftwareApplication with a free and a Pro offer", async ({ page }) => {
      const [app] = await jsonLd(page, l.app);
      expect(app["@type"]).toBe("SoftwareApplication");
      expect(app.applicationCategory).toBe("HealthApplication");
      expect(String(app.description).length).toBeGreaterThan(20);
      expectAbsoluteUrl(app.url);

      const [free, pro] = offersOf(app);
      expect(free.price).toBe("0");
      expect(pro.price).toMatch(/^\d+$/);
      expect(String(pro.description)).toContain(l.perMonth);
      for (const o of [free, pro]) expect(o.priceCurrency).toBe("HUF");
    });

    test("faq: one Question per visible question, each with an answer", async ({ page }) => {
      const [faq] = await jsonLd(page, l.faq);
      expect(faq["@type"]).toBe("FAQPage");
      const questions = faq.mainEntity as Node[];
      expect(questions.length).toBeGreaterThan(10);
      for (const q of questions) {
        expect(q["@type"]).toBe("Question");
        expect(String(q.name).trim().length).toBeGreaterThan(0);
        const answer = q.acceptedAnswer as Node;
        expect(answer["@type"]).toBe("Answer");
        expect(String(answer.text).trim().length).toBeGreaterThan(0);
      }
      const visible = await page.locator("main").innerText();
      for (const q of questions) expect(visible).toContain(String(q.name));
    });
  });
}
