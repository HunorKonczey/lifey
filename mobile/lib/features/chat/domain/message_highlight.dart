/// One run of a message: either part of a search hit or not.
class HighlightSegment {
  const HighlightSegment(this.text, {required this.match});

  final String text;
  final bool match;

  @override
  bool operator ==(Object other) =>
      other is HighlightSegment && other.text == text && other.match == match;

  @override
  int get hashCode => Object.hash(text, match);

  @override
  String toString() => match ? '[$text]' : text;
}

/// Base letter → the accented forms that fold onto it.
///
/// Grouped rather than written as two parallel strings so the pairs can't
/// silently drift out of alignment. Hungarian is the language that has to work
/// (á é í ó ö ő ú ü ű); the rest are the neighbours' letters that cost nothing
/// to add.
const _foldGroups = <String, String>{
  'a': 'áàâäãåāăą',
  'e': 'éèêëēĕėęě',
  'i': 'íìîïīĭįı',
  'o': 'óòôöõőōŏ',
  'u': 'úùûüűūŭů',
  'y': 'ýÿ',
  'c': 'çćč',
  'd': 'đď',
  'g': 'ğ',
  'l': 'łĺľ',
  'n': 'ñńň',
  'r': 'řŕ',
  's': 'šş',
  't': 'ťŧ',
  'z': 'žźż',
};

final Map<String, String> _foldTable = {
  for (final entry in _foldGroups.entries)
    for (final char in entry.value.split('')) char: entry.key,
};

/// Lowercased and stripped of accents, **one character in, one out** — which
/// is what lets a match found in the folded text be sliced out of the original
/// by the same indices.
String foldForSearch(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_foldTable[char] ?? char);
  }
  return buffer.toString();
}

/// Splits [text] into matched and unmatched runs so a search result can show
/// *where* the hit is.
///
/// Folds accents the same way the server's `unaccent` does: a search for
/// "labnap" returns a message reading "Lábnap", and highlighting nothing in it
/// would read as a bug.
List<HighlightSegment> highlightSegments(String text, String term) {
  final needle = foldForSearch(term.trim());
  if (needle.isEmpty || text.isEmpty) {
    return [HighlightSegment(text, match: false)];
  }

  final haystack = foldForSearch(text);
  final segments = <HighlightSegment>[];
  var cursor = 0;
  var at = haystack.indexOf(needle);

  while (at != -1) {
    if (at > cursor) {
      segments.add(HighlightSegment(text.substring(cursor, at), match: false));
    }
    segments.add(HighlightSegment(text.substring(at, at + needle.length), match: true));
    cursor = at + needle.length;
    at = haystack.indexOf(needle, cursor);
  }

  if (cursor < text.length) {
    segments.add(HighlightSegment(text.substring(cursor), match: false));
  }
  return segments.isEmpty ? [HighlightSegment(text, match: false)] : segments;
}
