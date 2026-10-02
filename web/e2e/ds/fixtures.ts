import { test as base, expect } from "@playwright/test";

/**
 * The gallery specs' `test`: identical to Playwright's, except that
 * `goto`/`reload` of `/dev/design` also wait for React to have hydrated
 * (`GalleryClient` sets `data-hydrated` on <html> from an effect).
 *
 * Why: the `ds` project runs against `next dev`, where the big gallery page
 * hydrates seconds after it paints — noticeably slower on a CI runner. A
 * click or keypress that lands on the server-rendered HTML before that has
 * no handler to run, so the spec fails in CI (and only there) as "element
 * not found" / "not focused" with nothing wrong in the component itself.
 */
export const test = base.extend({
  page: async ({ page }, use) => {
    const waitForHydration = () =>
      page.waitForFunction(() => document.documentElement.dataset.hydrated === "true", undefined, { timeout: 45_000 });

    const goto = page.goto.bind(page);
    page.goto = async (url, options) => {
      const response = await goto(url, options);
      if (String(url).startsWith("/dev/design")) await waitForHydration();
      return response;
    };
    const reload = page.reload.bind(page);
    page.reload = async (options) => {
      const response = await reload(options);
      if (new URL(page.url()).pathname.startsWith("/dev/design")) await waitForHydration();
      return response;
    };

    // eslint-disable-next-line react-hooks/rules-of-hooks -- Playwright's fixture `use`, not a React hook
    await use(page);
  },
});

export { expect };
