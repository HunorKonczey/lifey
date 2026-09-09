/// The later (more restrictive) of two history cutoffs. `null` means "no
/// restriction," so it always loses to a real date — combining a Pro user's
/// unlimited entitlement (`null`) with any UI-selected range cutoff simply
/// yields that range's own cutoff, and vice versa (`67` §3.2, D-P6).
DateTime? combineHistoryCutoffs(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}
