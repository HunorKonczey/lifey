/**
 * Lowercases and strips diacritics so accent-insensitive search ("a" matches
 * "á", "ă", etc.) works client-side the same way the backend's Postgres
 * `unaccent()` searches do. Only needed where a search filters an
 * already-fetched list in memory instead of hitting a backend `search` param.
 */
const COMBINING_DIACRITICS = /[̀-ͯ]/g;

export function normalizeForSearch(input: string): string {
  return input.toLowerCase().normalize("NFD").replace(COMBINING_DIACRITICS, "");
}
