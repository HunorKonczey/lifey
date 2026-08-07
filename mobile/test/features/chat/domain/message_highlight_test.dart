import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/domain/message_highlight.dart';

String _shown(List<HighlightSegment> segments) => segments.join();

void main() {
  group('foldForSearch', () {
    test('folds every Hungarian accent onto its base letter', () {
      expect(foldForSearch('Árvíztűrő Tükörfúrógép'), 'arvizturo tukorfurogep');
    });

    test('is one character in, one out — the whole reason indexes survive', () {
      const text = 'Erősítő';
      expect(foldForSearch(text).length, text.length);
    });
  });

  group('highlightSegments', () {
    test('marks the hit and leaves the rest alone', () {
      expect(_shown(highlightSegments('Holnap lábnap lesz', 'lábnap')), 'Holnap [lábnap] lesz');
    });

    test('matches without accents or case, but highlights the original text', () {
      // The server searches through `unaccent`, so a hit can look nothing like
      // the term — highlighting nothing in a returned result reads as a bug.
      expect(_shown(highlightSegments('Holnap Lábnap lesz', 'labnap')), 'Holnap [Lábnap] lesz');
    });

    test('marks every occurrence, not just the first', () {
      expect(_shown(highlightSegments('szett, szett, szett', 'szett')),
          '[szett], [szett], [szett]');
    });

    test('keeps the original string intact across accented matches', () {
      final segments = highlightSegments('Erősítő nap', 'erosito');

      expect(segments.map((s) => s.text).join(), 'Erősítő nap');
      expect(_shown(segments), '[Erősítő] nap');
    });

    test('returns the text untouched for an empty term', () {
      expect(highlightSegments('bármi', '  '), [const HighlightSegment('bármi', match: false)]);
    });

    test('returns the text untouched when nothing matches', () {
      expect(highlightSegments('bármi', 'zzz'), [const HighlightSegment('bármi', match: false)]);
    });

    test('handles an empty body — a caption-less picture can still be a result', () {
      expect(highlightSegments('', 'lábnap'), [const HighlightSegment('', match: false)]);
    });
  });
}
