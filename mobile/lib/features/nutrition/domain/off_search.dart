/// OpenFoodFacts name search (docs/84): the model of `GET /foods/off-search` and the pure rules the add-meal-entry
/// sheet follows — what is typed → the text that is sent, when a request is made at all, the search language and the
/// one note to show. Kept free of Flutter and Riverpod so they are plain unit tests; the controller that runs them is
/// `OffSearchController`.
library;

/// Fewer letters/digits than this and the backend answers 400 (`FoodController.MIN_OFF_SEARCH_LENGTH`).
const offSearchMinLength = 3;

/// Typing a word is one request, not one per letter — OpenFoodFacts allows few searches (docs/84 D7).
const offSearchDebounce = Duration(milliseconds: 400);

/// A product found by name. Not a local-db entity: it becomes a [Food] only when the user logs it.
class OffSearchItem {
  const OffSearchItem({
    required this.barcode,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    this.brand,
    this.carbsPer100g,
    this.fatPer100g,
    this.fiberPer100g,
    this.sugarPer100g,
  });

  final String barcode;
  final String name;
  final String? brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final double? fiberPer100g;
  final double? sugarPer100g;

  factory OffSearchItem.fromJson(Map<String, dynamic> json) {
    return OffSearchItem(
      barcode: json['barcode'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num?)?.toDouble(),
      fatPer100g: (json['fatPer100g'] as num?)?.toDouble(),
      fiberPer100g: (json['fiberPer100g'] as num?)?.toDouble(),
      sugarPer100g: (json['sugarPer100g'] as num?)?.toDouble(),
    );
  }
}

/// How the backend says the search went. Anything but [ok] comes with no items; an unknown value reads as
/// [unavailable] so a newer backend never breaks the sheet.
enum OffSearchStatus {
  ok,
  unavailable,
  rateLimited;

  static OffSearchStatus parse(String? value) => switch (value) {
        'OK' => ok,
        'RATE_LIMITED' => rateLimited,
        _ => unavailable,
      };
}

class OffSearchResult {
  const OffSearchResult({
    required this.status,
    required this.language,
    required this.fellBackToEnglish,
    required this.items,
  });

  final OffSearchStatus status;

  /// The language the items were searched in, `hu` or `en`.
  final String language;

  /// True only when the user's-language search found nothing and the English one did.
  final bool fellBackToEnglish;
  final List<OffSearchItem> items;

  factory OffSearchResult.fromJson(Map<String, dynamic> json) {
    final status = OffSearchStatus.parse(json['status'] as String?);
    return OffSearchResult(
      status: status,
      language: (json['language'] as String?) ?? 'en',
      fellBackToEnglish: (json['fellBackToEnglish'] as bool?) ?? false,
      // Whatever the status, items only count when OK — a defensive reading of "anything but OK has none".
      items: status == OffSearchStatus.ok
          ? [for (final i in (json['items'] as List<dynamic>? ?? const [])) OffSearchItem.fromJson(i as Map<String, dynamic>)]
          : const [],
    );
  }
}

final _disallowed = RegExp(r"[^\p{L}\p{N}'’\- ]", unicode: true);
// A hyphen that is not between two letters/digits means "NOT" to the search syntax, or is noise.
final _looseHyphen = RegExp(r'(?<![\p{L}\p{N}])-|-(?![\p{L}\p{N}])', unicode: true);
final _spaces = RegExp(r'\s+');
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// What is sent to the backend: the same cleaning the backend does (`OffSearchQuery.sanitize`) — lower case, accents
/// kept, only letters, digits, spaces, apostrophes and hyphens inside a word. Doing it here as well makes "Tej" and
/// "tej" one cache entry and keeps the 3-letter rule honest on both sides.
String sanitizeOffQuery(String raw) {
  return raw
      .toLowerCase()
      .replaceAll(_disallowed, ' ')
      .replaceAll(_looseHyphen, ' ')
      .replaceAll(_spaces, ' ')
      .trim();
}

/// Enough to search: at least 3 letters or digits in the cleaned text (spaces and hyphens do not count).
bool isOffSearchable(String text) {
  return _letterOrDigit.allMatches(sanitizeOffQuery(text)).length >= offSearchMinLength;
}

/// The backend searches `hu` or `en`; the app's language decides (the backend treats anything else as `en` too).
String offSearchLang(String languageCode) => languageCode.toLowerCase() == 'hu' ? 'hu' : 'en';

/// The one line to show under the OpenFoodFacts rows, if any (docs/84 §3.1). A failed request reads as unavailable.
enum OffNote { fellBack, unavailable, rateLimited }

OffNote? offSearchNote(OffSearchResult? result, {required bool failed}) {
  if (failed) return OffNote.unavailable;
  if (result == null) return null;
  return switch (result.status) {
    OffSearchStatus.unavailable => OffNote.unavailable,
    OffSearchStatus.rateLimited => OffNote.rateLimited,
    OffSearchStatus.ok => result.fellBackToEnglish ? OffNote.fellBack : null,
  };
}
