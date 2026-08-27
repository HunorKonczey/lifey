import { hasLocale } from "next-intl";
import { getRequestConfig } from "next-intl/server";
import { routing } from "./routing";

/**
 * Request-scoped i18n config for the marketing tree's server components
 * (`getTranslations`, `getFormatter`, ...). Loads `messages/marketing.*.json`
 * — deliberately separate from the authenticated app's `messages/{en,hu}.json`
 * (docs/landing_page/65 §D-W5), which stay client-side and untouched by this.
 */
export default getRequestConfig(async ({ requestLocale }) => {
  const requested = await requestLocale;
  const locale = hasLocale(routing.locales, requested) ? requested : routing.defaultLocale;

  return {
    locale,
    messages: (await import(`../../messages/marketing.${locale}.json`)).default,
  };
});
