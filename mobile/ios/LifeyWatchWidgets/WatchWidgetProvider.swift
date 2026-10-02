import SwiftUI
import WidgetKit

/// One entry of either widget: the snapshot the app last published.
struct WorkoutEntry: TimelineEntry {
  let date: Date
  let snapshot: WatchWidgetSnapshot
}

/// Shared by the Smart Stack widget and the complication. The timelines need no per-second entries — the live
/// elapsed time and the rest countdown are system-rendered timers — only the moment a rest ends is a second
/// entry, so the layout returns to "active" without waiting for the app to publish.
struct WorkoutProvider: TimelineProvider {
  func placeholder(in context: Context) -> WorkoutEntry {
    WorkoutEntry(date: Date(), snapshot: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
    completion(WorkoutEntry(date: Date(), snapshot: context.isPreview ? .sample : WatchWidgetStore.read()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
    let now = Date()
    let snapshot = WatchWidgetStore.read(now: now)
    var entries = [WorkoutEntry(date: now, snapshot: snapshot)]
    if snapshot.phase == .resting, let ends = snapshot.restEndsAt, ends > now {
      entries.append(WorkoutEntry(date: ends, snapshot: snapshot.endingRest()))
    }
    // The app reloads the timeline on every meaningful change; this is only the safety net.
    completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
  }
}
