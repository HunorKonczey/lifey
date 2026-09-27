import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/format/emphasis.dart';

void main() {
  const bold = TextStyle(fontWeight: FontWeight.w700);

  List<({String text, bool bold})> parts(TextSpan span) => [
        for (final c in span.children!.cast<TextSpan>())
          (text: c.text!, bold: c.style == bold),
      ];

  test('swaps each marker for its value in the emphasis style, in the translator\'s word order', () {
    final sentence = 'Eaten ${Emphasis.marker(0)} · Goal ${Emphasis.marker(1)}';
    expect(parts(Emphasis.span(sentence, ['621', '2 360'], bold)), [
      (text: 'Eaten ', bold: false),
      (text: '621', bold: true),
      (text: ' · Goal ', bold: false),
      (text: '2 360', bold: true),
    ]);
  });

  test('a language that puts the number first still works', () {
    final sentence = '${Emphasis.marker(0)} kcal átlag';
    expect(parts(Emphasis.span(sentence, ['1 631'], bold)), [
      (text: '1 631', bold: true),
      (text: ' kcal átlag', bold: false),
    ]);
  });

  test('text without markers passes through unchanged', () {
    expect(parts(Emphasis.span('No numbers here', ['1'], bold)), [(text: 'No numbers here', bold: false)]);
  });

  test('accented and non-BMP text around the markers is kept intact', () {
    final sentence = 'Fehérje 🥩 ${Emphasis.marker(0)} g';
    expect(parts(Emphasis.span(sentence, ['29'], bold)), [
      (text: 'Fehérje 🥩 ', bold: false),
      (text: '29', bold: true),
      (text: ' g', bold: false),
    ]);
  });
}
