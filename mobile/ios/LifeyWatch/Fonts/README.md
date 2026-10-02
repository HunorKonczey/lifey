# Plus Jakarta Sans — numeral subsets

Numbers only (D-X0.6); every word stays in the system font. Licence: SIL OFL 1.1 (`OFL.txt`).
The same files are committed for Wear OS (`mobile/android/wear/src/main/res/font/`) and a JVM test
asserts they are byte-identical.

Subset glyphs: `0-9 : . , + - − – — / ~ % ×`, space, NBSP, NNBSP (U+00A0, U+202F); the ExtraBold
subset also has `L i f e y` for the idle wordmark. Features kept: `tnum`, `kern`, `liga`.

```bash
U='U+0030-0039,U+003A,U+002E,U+002C,U+002B,U+002D,U+2212,U+2013,U+2014,U+002F,U+007E,U+0025,U+00D7,U+0020,U+00A0,U+202F'
pyftsubset mobile/assets/fonts/PlusJakartaSans-ExtraBold.ttf --unicodes="$U,U+004C,U+0069,U+0066,U+0065,U+0079" \
  --layout-features='tnum,kern,liga' --output-file=PlusJakartaSans-ExtraBold-numerals.ttf
pyftsubset mobile/assets/fonts/PlusJakartaSans-Bold.ttf --unicodes="$U" \
  --layout-features='tnum,kern,liga' --output-file=PlusJakartaSans-Bold-numerals.ttf
```

`PlusJakartaSans-Light-numerals.ttf` (weight 300, Always-On numbers) is **not yet here**: the Light weight
is not in `mobile/assets/fonts/` and fetching it from the upstream OFL release needs the owner's OK
(plan §10 Q4). Until it lands, `Font.lifeyAodHero` falls back to the Bold subset.
