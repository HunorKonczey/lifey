/// The tabs of the client detail screen (docs/chat/41 T2, frame C1).
///
/// The web has six; T2 shipped the five read-only data views and T3 added
/// Workouts, the first *writing* surface, and T5 the schedule. A tab appears
/// here on the iteration that makes it real, never before.
///
/// The stored name is part of a persisted preference (the last tab per
/// client), so renaming a value silently drops that client's memory back to
/// the default. That is harmless, but it is why the name is written down
/// rather than the index: reordering the enum must not point an old
/// preference at a different tab.
enum ClientDetailTab {
  overview('overview'),
  statistics('statistics'),
  workouts('workouts'),
  nutrition('nutrition'),
  steps('steps'),
  weight('weight'),
  schedule('schedule');

  const ClientDetailTab(this.storageKey);

  final String storageKey;

  static ClientDetailTab? fromStorageKey(String? key) {
    if (key == null) return null;
    for (final tab in values) {
      if (tab.storageKey == key) return tab;
    }
    return null;
  }
}
