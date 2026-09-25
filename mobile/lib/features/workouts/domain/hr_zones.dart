/// Heart-rate zones for the *live* cardio screen — the current beat measured
/// against a maximum heart rate, in five bands of the maximum
/// (docs/redesign/77-mobile-redesign-plan.md R3.8).
///
/// The phone has no measured maximum, so [maxHeartRateForAge] is the classic
/// 220 − age estimate; the live row shows nothing when the age is unknown.
/// (A finished session's zone times come from the watch, against the
/// profile's own maximum — see `HrZoneBreakdown`.)
const int kHeartRateZoneCount = 5;

/// 220 − [age]; null for an age no adult has (so a bad birth date can't show a
/// nonsense zone).
int? maxHeartRateForAge(int age) => age >= 10 && age <= 100 ? 220 - age : null;

/// Whole years between [birthDate] and [now].
int ageOn(DateTime birthDate, DateTime now) {
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) age--;
  return age;
}

/// The zone (1–5) of [bpm] against [maxHeartRate]: up to 60 % of the maximum is
/// Z1, up to 70 % Z2, up to 80 % Z3, up to 90 % Z4, above that Z5.
int heartRateZone(num bpm, num maxHeartRate) {
  final fraction = bpm / maxHeartRate;
  if (fraction <= 0.6) return 1;
  if (fraction <= 0.7) return 2;
  if (fraction <= 0.8) return 3;
  if (fraction <= 0.9) return 4;
  return 5;
}
