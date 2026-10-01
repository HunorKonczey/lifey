/** Lower-cased and stripped of accents, so "kacsa" finds "Kacsamell" and "egg" finds "Éger". */
function plain(text: string): string {
  return text.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase();
}

/** Does a food's name contain every word of the search (any order, accents and case ignored)? */
export function matchesFoodSearch(name: string, search: string): boolean {
  const words = plain(search).split(/\s+/).filter(Boolean);
  if (words.length === 0) return true;
  const haystack = plain(name);
  return words.every((w) => haystack.includes(w));
}
