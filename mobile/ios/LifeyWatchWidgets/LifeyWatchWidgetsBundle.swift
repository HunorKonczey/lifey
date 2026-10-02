import SwiftUI
import WidgetKit

/// Entry point of the watch widget extension (redesign X2.o1 / X2.o2): the Smart Stack widget and the circular
/// complication share one provider and one snapshot.
@main
struct LifeyWatchWidgetsBundle: WidgetBundle {
  var body: some Widget {
    WorkoutSmartStackWidget()
    LifeyCircularComplication()
  }
}
