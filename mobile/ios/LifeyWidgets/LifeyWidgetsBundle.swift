import WidgetKit
import SwiftUI

@main
struct LifeyWidgetsBundle: WidgetBundle {
  var body: some Widget {
    TodaySummaryWidget()
    if #available(iOS 16.1, *) {
      WorkoutLiveActivity()
    }
  }
}
