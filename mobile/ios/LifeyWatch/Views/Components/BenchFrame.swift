import SwiftUI

/// Bench frame (frame 04/13): a 4 pt clay stroke following the display's corner radius, shown while a team
/// sport player is on the bench. Always-On: 2 pt at 60 %.
struct BenchFrame: View {
  var isAmbient = false

  var body: some View {
    ContainerRelativeShape()
      .strokeBorder(LifeyColors.clay.opacity(isAmbient ? 0.6 : 1), lineWidth: isAmbient ? 2 : 4)
      .ignoresSafeArea()
      .allowsHitTesting(false)
  }
}
