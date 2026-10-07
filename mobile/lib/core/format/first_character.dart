/// The first character of [text], upper-cased, for a monogram: whole code
/// points, so a name that starts with an emoji ("💪 Joe") gives the emoji, not
/// half of it. `text[0]` returns the lone first surrogate, which Flutter's
/// text layer refuses ("string is not well-formed UTF-16") and which shows as a
/// replacement character in a release build.
///
/// [text] must not be empty.
String firstCharacterUpper(String text) =>
    String.fromCharCode(text.runes.first).toUpperCase();
