/// Diacritic-to-base-letter map covering Hungarian (á, é, í, ó, ö, ő, ú, ü, ű)
/// and Romanian (ă, â, î, ș, ț and their cedilla variants ş, ţ), plus the
/// wider Latin-1/Latin Extended-A accents a user might type or a food/recipe
/// name might contain.
const Map<String, String> _diacriticsMap = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ă': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ő': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ű': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ñ': 'n',
  'ç': 'c',
  'ș': 's', 'ş': 's',
  'ț': 't', 'ţ': 't',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
  'ć': 'c', 'č': 'c',
  'š': 's',
  'ł': 'l',
};

/// Lowercases and strips diacritics so accent-insensitive search ("a" matches
/// "á", "ă", etc.) works the same way the backend's Postgres `unaccent()`
/// searches do (see FoodRepository/RecipeRepository). Apply to both the
/// search query and the candidate name before comparing.
String normalizeForSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticsMap[char] ?? char);
  }
  return buffer.toString();
}
