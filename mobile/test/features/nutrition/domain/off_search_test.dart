import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/off_search.dart';

void main() {
  // The same cases as the backend's OffSearchQueryTest and the web's offSearch.test.ts: all three sides must clean text alike.
  group('sanitizeOffQuery — parity with the backend and the web', () {
    test('keeps accents and lower-cases', () {
      expect(sanitizeOffQuery('Túró Rudi'), 'túró rudi');
      expect(sanitizeOffQuery('Sütőtök'), 'sütőtök');
    });

    test('drops search-syntax characters', () {
      expect(sanitizeOffQuery('tej:'), 'tej');
      expect(sanitizeOffQuery('categories_tags:"en:beverages" tej'), 'categories tags en beverages tej');
      expect(sanitizeOffQuery('"tej'), 'tej');
      expect(sanitizeOffQuery('tej*'), 'tej');
      expect(sanitizeOffQuery('(tej OR sajt) ~2 ^3'), 'tej or sajt 2 3');
    });

    test('lower-casing defuses upper-case operators', () {
      expect(sanitizeOffQuery('a OR'), 'a or');
      expect(sanitizeOffQuery('tej AND NOT sajt'), 'tej and not sajt');
    });

    test('keeps a hyphen or apostrophe inside a word, drops one that would mean NOT', () {
      expect(sanitizeOffQuery('coca-cola'), 'coca-cola');
      expect(sanitizeOffQuery("lay's"), "lay's");
      expect(sanitizeOffQuery('-tej'), 'tej');
      expect(sanitizeOffQuery('tej -sajt'), 'tej sajt');
      expect(sanitizeOffQuery('tej - sajt'), 'tej sajt');
      expect(sanitizeOffQuery('tej-'), 'tej');
    });

    test('collapses and trims spaces', () {
      expect(sanitizeOffQuery('   görög    joghurt \t'), 'görög joghurt');
    });

    test('gives an empty string when nothing searchable is left', () {
      expect(sanitizeOffQuery(''), '');
      expect(sanitizeOffQuery('   '), '');
      expect(sanitizeOffQuery(':"*()-'), '');
    });
  });

  group('isOffSearchable — the 3 letters or digits rule', () {
    test('is exactly 3 letters or digits', () {
      expect(offSearchMinLength, 3);
      expect(isOffSearchable('tej'), isTrue);
      expect(isOffSearchable('túró'), isTrue);
      expect(isOffSearchable('a1b'), isTrue);
      expect(isOffSearchable('123'), isTrue);
    });

    test('is not met by fewer, nor by spaces, hyphens or punctuation making up the length', () {
      for (final text in ['', 'ab', 'a b', '  ab  ', 'a-b', ':::', '"a"', 'ab:*']) {
        expect(isOffSearchable(text), isFalse, reason: '"$text"');
      }
    });

    test('judges the cleaned text, so what the backend would reject is never sent', () {
      expect(isOffSearchable('a:b::'), isFalse);
      expect(isOffSearchable('a:b:c'), isTrue);
    });
  });

  test('offSearchLang: Hungarian searches Hungarian, everything else English', () {
    expect(offSearchLang('hu'), 'hu');
    expect(offSearchLang('HU'), 'hu');
    expect(offSearchLang('en'), 'en');
    expect(offSearchLang('de'), 'en');
  });

  group('OffSearchResult.fromJson', () {
    final item = {
      'barcode': '4056489827702',
      'name': 'Csirkemell',
      'brand': 'Pikok',
      'caloriesPer100g': 110,
      'proteinPer100g': 14.0,
      'carbsPer100g': 2.4,
      'fatPer100g': null,
    };

    test('reads a full answer, ints as doubles and a missing carbs or fat as null', () {
      final r = OffSearchResult.fromJson({
        'status': 'OK',
        'language': 'en',
        'fellBackToEnglish': true,
        'items': [item],
      });

      expect(r.status, OffSearchStatus.ok);
      expect(r.language, 'en');
      expect(r.fellBackToEnglish, isTrue);
      expect(r.items, hasLength(1));
      expect(r.items.single.name, 'Csirkemell');
      expect(r.items.single.brand, 'Pikok');
      expect(r.items.single.caloriesPer100g, 110.0);
      expect(r.items.single.carbsPer100g, 2.4);
      expect(r.items.single.fatPer100g, isNull);
    });

    test('a brand may be missing', () {
      final r = OffSearchResult.fromJson({'status': 'OK', 'language': 'hu', 'fellBackToEnglish': false, 'items': [{...item, 'brand': null}]});

      expect(r.items.single.brand, isNull);
    });

    test('UNAVAILABLE and RATE_LIMITED have no items, whatever the body carries', () {
      final unavailable = OffSearchResult.fromJson({'status': 'UNAVAILABLE', 'language': 'hu', 'fellBackToEnglish': false, 'items': [item]});
      final limited = OffSearchResult.fromJson({'status': 'RATE_LIMITED', 'language': 'hu', 'fellBackToEnglish': false, 'items': []});

      expect(unavailable.status, OffSearchStatus.unavailable);
      expect(unavailable.items, isEmpty);
      expect(limited.status, OffSearchStatus.rateLimited);
    });

    test('an unknown status or a missing one reads as unavailable, never a crash', () {
      expect(OffSearchResult.fromJson({'status': 'SOMETHING_NEW'}).status, OffSearchStatus.unavailable);
      expect(OffSearchResult.fromJson(const {}).status, OffSearchStatus.unavailable);
    });
  });

  group('offSearchNote — the one line under the OpenFoodFacts rows', () {
    OffSearchResult result(OffSearchStatus status, {bool fellBack = false}) =>
        OffSearchResult(status: status, language: 'hu', fellBackToEnglish: fellBack, items: const []);

    test('none for a plain answer, and before there is one', () {
      expect(offSearchNote(result(OffSearchStatus.ok), failed: false), isNull);
      expect(offSearchNote(null, failed: false), isNull);
    });

    test('names the English fallback', () {
      expect(offSearchNote(result(OffSearchStatus.ok, fellBack: true), failed: false), OffNote.fellBack);
    });

    test('unavailable and rate limited for those statuses', () {
      expect(offSearchNote(result(OffSearchStatus.unavailable), failed: false), OffNote.unavailable);
      expect(offSearchNote(result(OffSearchStatus.rateLimited), failed: false), OffNote.rateLimited);
    });

    test('a failed request reads as unavailable, whatever an older answer said', () {
      expect(offSearchNote(null, failed: true), OffNote.unavailable);
      expect(offSearchNote(result(OffSearchStatus.ok, fellBack: true), failed: true), OffNote.unavailable);
    });
  });
}
