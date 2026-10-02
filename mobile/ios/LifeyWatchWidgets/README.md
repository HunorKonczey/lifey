# LifeyWatchWidgets (not wired, not compiled)

Sources for the watch Smart Stack widget (AW2.24, plan X2.o1) and the circular complication (AW2.25, X2.o2).
Nothing here belongs to an Xcode target yet and none of it has been compiled — it was written without a Mac.
The folder is outside every target, so the iOS / watch build is unaffected until the steps below are done.

| File | Role |
|---|---|
| `WatchWidgetSnapshot.swift` | Codable snapshot + App Group store (shared by the app and the extension) |
| `WatchWidgetPublisher.swift` | Watch-app side: observes `WorkoutManager`, writes the snapshot, reloads timelines |
| `WatchWidgetProvider.swift` | Shared `TimelineProvider` (extra entry when a rest ends, 15 min safety refresh) |
| `WorkoutSmartStackWidget.swift` | `accessoryRectangular` widget |
| `LifeyCircularComplication.swift` | `accessoryCircular` complication |
| `LifeyWatchWidgetsBundle.swift` | `@main` WidgetBundle |
| `Info.plist`, `LifeyWatchWidgets.entitlements`, `Localizable.xcstrings` | Extension resources (en, hu) |

## Mac / Xcode steps

1. **Target**: File ▸ New ▸ Target ▸ watchOS ▸ *Widget Extension* (no configuration intent, no Live Activity).
   Name `LifeyWatchWidgets`, bundle id `com.khunor.lifey.watchkitapp.widgets`, embed in `LifeyWatch`.
   Delete the generated Swift files; add the files of this folder to the new target and use this `Info.plist`.
2. **App Group**: register `group.com.khunor.lifey.watch` in the developer portal (the phone's
   `group.com.khunor.lifey` is not available on watchOS). Add the capability to both the `LifeyWatch` and the
   extension target; the extension uses `LifeyWatchWidgets.entitlements`, add the group to
   `LifeyWatch.entitlements` as well.
3. **Shared files**: give `WatchWidgetSnapshot.swift` and `LifeyColors.swift` (from `LifeyWatch/Theme`) target
   membership in the extension; `WatchWidgetPublisher.swift` belongs to the `LifeyWatch` app target only
   (it imports `WorkoutManager`) — also add `WatchWidgetSnapshot.swift` to the app target.
4. **Fonts** (optional): add `PlusJakartaSans-ExtraBold-numerals.ttf` to the extension (Copy Bundle Resources).
   Without it `Font.custom` silently falls back to the system font.
5. **Hook**: in the `LifeyWatchApp` root, once: `WatchWidgetPublisher.shared.start(observing: workoutManager)`.
   Add `.onOpenURL` handling `lifey-watch://quick-strength` (open the start picker) and `lifey-watch://workout`
   (nothing to do; just foreground the app).
6. **Check** with `xcodebuild` + 45/41 mm simulators: Xcode ▸ Product ▸ Scheme ▸ the widget extension, run
   with the Smart Stack / a circular complication slot; test the idle, active, resting and stale states
   (`WatchWidgetSnapshot.sample` is the preview fixture).

Known unverified points: `String(format:)` with `%@` and positional arguments in `widget_exercise_sets`;
`ProgressView(timerInterval:countsDown:)` label closures; the exact widget font fallback.
