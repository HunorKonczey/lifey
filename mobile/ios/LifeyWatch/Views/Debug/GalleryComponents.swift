#if DEBUG
  import SwiftUI

  /// Gallery sections for the 04 components, one `…Gallery` view per component group (D-X0.11). Each shows
  /// every state at the gallery's current width.

  struct HeaderChipGallery: View {
    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.md) {
        WatchHeaderChip(icon: "dumbbell", label: "Erőedzés")
        WatchHeaderChip(icon: "dumbbell", label: "Erőedzés", isPaused: true)
        WatchHeaderChip(icon: "figure.run", label: "Futás", accent: LifeyColors.calories)
        WatchHeaderChip(icon: "dumbbell", label: "Erőedzés", standaloneMark: .idle)
        WatchHeaderChip(icon: "dumbbell", label: "Erőedzés", standaloneMark: .tapped)
      }
    }
  }

  struct MetricReadingGallery: View {
    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.md) {
        WatchMetricReading(
          icon: "heart.fill", iconTint: LifeyColors.heart, number: "128", unit: "bpm", level: .metric)
        WatchMetricReading(icon: "flame.fill", iconTint: LifeyColors.calories, number: "212", unit: "kcal")
      }
    }
  }

  struct SegmentBarGallery: View {
    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.md) {
        SetSegmentBar(done: 2, total: 4)
        SetSegmentBar(done: 3, total: 4, justLoggedIndex: 2)
        SetSegmentBar(done: 5, total: 8)
        SetSegmentBar(done: 0, total: 0, freeFormText: "3. szett · 24 ism.")
      }
    }
  }
#endif

#if DEBUG
  struct HeartRateSlotGallery: View {
    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.md) {
        HeartRateSlot(bpm: 128).border(LifeyColors.outline, width: 0.5)
        HeartRateSlot(bpm: nil).border(LifeyColors.outline, width: 0.5)
      }
    }
  }
#endif
