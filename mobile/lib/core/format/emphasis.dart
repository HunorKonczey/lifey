import 'package:flutter/painting.dart';

/// Sets numbers inside a translated sentence in a stronger style — "avg
/// **1 631** kcal", "Eaten **621** · Goal **2 360**" — without splitting the
/// sentence into fragments for translators.
///
/// The ARB string keeps its real placeholders. The caller renders it with
/// [marker]s in their place, and [span] then swaps each marker for the real
/// value in the emphasis style, so word order and suffixes stay the
/// translator's business:
///
/// ```dart
/// final m = [Emphasis.marker(0), Emphasis.marker(1)];
/// Text.rich(Emphasis.span(l10n.eatenGoal(m[0], m[1]), [eaten, goal], bold));
/// ```
abstract final class Emphasis {
  // Private-use code points: they can't occur in a translation.
  static const int _base = 0xE000;

  /// The stand-in for the [index]th value while the sentence is rendered.
  static String marker(int index) => String.fromCharCode(_base + index);

  /// [template] with each [marker] replaced by its entry of [values], drawn
  /// in [emphasis]; the rest of the sentence inherits the surrounding style.
  static TextSpan span(String template, List<String> values, TextStyle emphasis) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }

    for (final rune in template.runes) {
      final index = rune - _base;
      if (index >= 0 && index < values.length) {
        flush();
        spans.add(TextSpan(text: values[index], style: emphasis));
      } else {
        buffer.writeCharCode(rune);
      }
    }
    flush();
    return TextSpan(children: spans);
  }
}
