import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/format/parse_decimal.dart';

void main() {
  group('parseDecimal', () {
    test('a comma and a point are the same decimal', () {
      expect(parseDecimal('82,5'), 82.5);
      expect(parseDecimal('82.5'), 82.5);
      expect(parseDecimal('0,5'), 0.5);
      expect(parseDecimal(',5'), 0.5);
      expect(parseDecimal('.5'), 0.5);
      expect(parseDecimal('5,'), 5.0);
      expect(parseDecimal('5.'), 5.0);
    });

    test('whole numbers, negatives and surrounding or inner spaces', () {
      expect(parseDecimal('82'), 82);
      expect(parseDecimal('-3,5'), -3.5);
      expect(parseDecimal('  1 234,5 '), 1234.5);
    });

    test('null for empty text and null', () {
      expect(parseDecimal(null), isNull);
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('   '), isNull);
      expect(parseDecimal('-'), isNull);
    });

    test('null for two separators, exponents and words', () {
      expect(parseDecimal('1,2,3'), isNull);
      expect(parseDecimal('1.2.3'), isNull);
      expect(parseDecimal('1,234.5'), isNull);
      expect(parseDecimal('1e3'), isNull);
      expect(parseDecimal('Infinity'), isNull);
      expect(parseDecimal('abc'), isNull);
    });
  });
}
