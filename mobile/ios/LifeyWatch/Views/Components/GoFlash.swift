import SwiftUI

/// "Mehet!" rim flash (frame 04/07, D3): instead of a full green screen, a thick primary rim follows the
/// display shape and a white "Mehet!" sits in the middle, over any page. 150 ms in · 250 ms hold · 700 ms
/// out — unchanged timing. Reduce Motion: the rim is static for 1.1 s. The haptic fires independently in
/// `WorkoutManager`; this is purely visual.
struct GoFlash: View {
  /// Replaying the flash (gallery) = changing this value.
  var replayToken = 0

  @State private var opacity: Double = 0
  @Environment(\.watchMetrics) private var metrics
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      ContainerRelativeShape()
        .strokeBorder(LifeyColors.primary, lineWidth: 8)
      Text("rest_go_label")
        .lifeyHero(metrics, dense: true)
        .foregroundColor(LifeyColors.text)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
    .opacity(opacity)
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .onAppear(perform: play)
    .onChange(of: replayToken) { _, _ in play() }
  }

  private func play() {
    if reduceMotion {
      opacity = 1
      DispatchQueue.main.asyncAfter(deadline: .now() + LifeyMotion.goStaticSeconds) { opacity = 0 }
      return
    }
    opacity = 0
    withAnimation(LifeyMotion.enter(LifeyMotion.Duration.goIn)) { opacity = 1 }
    DispatchQueue.main.asyncAfter(
      deadline: .now() + LifeyMotion.Duration.goIn + LifeyMotion.Duration.goHold
    ) {
      withAnimation(LifeyMotion.exit(LifeyMotion.Duration.goOut)) { opacity = 0 }
    }
  }
}
