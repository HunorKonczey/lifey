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

#if DEBUG
  struct CircleButtonGallery: View {
    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.lg) {
        HStack(alignment: .top, spacing: LifeySpacing.md) {
          CircleButton(style: .primary, icon: "plus", label: "+1 szett") {}
          CircleButton(style: .raised, icon: "slider.horizontal.3", label: "Módosítás", iconTint: LifeyColors.clay) {}
        }
        HStack(alignment: .top, spacing: LifeySpacing.md) {
          CircleButton(style: .primary, icon: "plus", label: "+1 szett", isGhosted: true) {}
          CircleButton(style: .raised, icon: "slider.horizontal.3", label: "Módosítás", isGhosted: true) {}
        }
        HStack(alignment: .top, spacing: LifeySpacing.md) {
          CircleButton(style: .successTint, icon: "checkmark", label: "3/4 szett") {}
          CircleButton(style: .errorTint, icon: "xmark", label: "Vége") {}
          CircleButton(style: .control, icon: "pause.fill", label: "Szünet") {}
        }
      }
    }
  }

  struct StatusPillGallery: View {
    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.sm) {
        StatusPill(kind: .logged, text: "Naplózva")
        StatusPill(kind: .pending, text: "Naplózás…")
        StatusPill(kind: .failed, text: "Nem sikerült — próbáld újra")
        StatusPill(kind: .unreachable, text: "Nincs kapcsolat a telefonnal")
        StatusPill(kind: .handoff, text: "Folytatás a telefonon…")
      }
    }
  }
#endif
