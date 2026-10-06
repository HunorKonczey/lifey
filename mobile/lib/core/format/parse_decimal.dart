/// What a person typed into a number field → a number: a comma and a point
/// both mean the decimal separator, whatever the app language or the keyboard
/// ("82,5" and "82.5" are the same weight). Spaces are ignored; `null` for
/// empty text, anything that is not a plain number (two separators, "1e3",
/// "abc") and anything infinite.
///
/// Every decimal field parses through this, so the fields cannot disagree.
double? parseDecimal(String? text) {
  if (text == null) return null;
  final normalized = text.replaceAll(RegExp(r'\s'), '').replaceFirst(',', '.');
  if (!RegExp(r'^-?(\d+\.?\d*|\.\d+)$').hasMatch(normalized)) return null;
  return double.tryParse(normalized);
}
