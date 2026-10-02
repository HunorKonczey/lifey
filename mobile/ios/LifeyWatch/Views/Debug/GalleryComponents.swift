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
        SetSegmentBar(title: "Fekvenyomás", done: 2, total: 4)
        SetSegmentBar(title: "Fekvenyomás", done: 3, total: 4, justLoggedIndex: 2)
        SetSegmentBar(title: "Guggolás", done: 5, total: 8)
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

#if DEBUG
  struct RestCountdownGallery: View {
    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.lg) {
        RestCountdown(remainingSeconds: 47, totalSeconds: 90)
        RestCountdown(remainingSeconds: 4, totalSeconds: 90)
      }
    }
  }

  struct GoFlashGallery: View {
    @State private var token = 0
    var body: some View {
      VStack {
        Button("Replay") { token += 1 }
        ZStack {
          RoundedRectangle(cornerRadius: LifeyShapes.hero).fill(LifeyColors.card)
          GoFlash(replayToken: token).containerShape(RoundedRectangle(cornerRadius: LifeyShapes.hero))
        }
        .frame(height: 140)
      }
    }
  }

  struct StepperGallery: View {
    @State private var reps = 8.0
    @State private var low = 1.0
    @State private var high = 99.0
    @State private var weight = 102.5
    @State private var effort = 7
    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.lg) {
        ValueStepper(value: $reps, range: 1...99, step: 1, format: { "\(Int($0))" }, unit: "ismétlés")
        ValueStepper(value: $low, range: 1...99, step: 1, format: { "\(Int($0))" })
        ValueStepper(value: $high, range: 1...99, step: 1, format: { "\(Int($0))" })
        ValueStepper(
          value: $weight, range: 0...500, step: 2.5,
          format: { String(format: "%g", $0).replacingOccurrences(of: ".", with: ",") }, unit: "kg")
        EffortScale(value: $effort)
      }
    }
  }
#endif

#if DEBUG
  struct ListRowGallery: View {
    var body: some View {
      VStack(spacing: LifeySpacing.sm) {
        ListRow(title: "Gyors erőedzés", leading: .holder(icon: "bolt.fill"), isHighlighted: true) {}
        ListRow(title: "Push nap — mell, vállak és tricepsz", onClick: {}, subtitle: "5 gyakorlat", showsChevron: true)
        ListRow(title: "Futás", onClick: {}, leading: .tintedCircle(icon: "figure.run", accent: LifeyColors.calories))
        ListRow(title: "Minden edzéstípus", onClick: {}, leading: .controlCircle(icon: "square.grid.2x2.fill"), showsChevron: true)
        ListRow(title: "Fekvenyomás", onClick: {}, showsCheck: true)
        HStack { CompactChip(title: "Gyakorlatok", icon: "list.bullet") {}; CompactChip(title: "Gyakorlatok", isGhosted: true) {} }
      }
    }
  }

  struct SummaryGallery: View {
    var body: some View {
      VStack(spacing: LifeySpacing.sm) {
        SummaryTile(number: 148, format: { "\(Int($0.rounded()))" }, label: "átlag bpm", tint: LifeyColors.heart)
        SyncRow(isSynced: false, title: "Szinkronizálás a telefonra", subtitle: "2 edzés vár szinkronizálásra")
        SyncRow(isSynced: true, title: "Telefonra szinkronizálva")
      }
    }
  }

  struct StructuralGallery: View {
    var body: some View {
      VStack(spacing: LifeySpacing.md) {
        ZStack {
          RoundedRectangle(cornerRadius: LifeyShapes.hero).fill(LifeyColors.bg)
          BenchFrame().containerShape(RoundedRectangle(cornerRadius: LifeyShapes.hero))
          Text(verbatim: "Padon").foregroundColor(LifeyColors.clay)
        }
        .frame(height: 90)
        CardioField(value: "5:12", label: "Tempó /km")
        CardioField(value: "148", label: "Átlagos teljesítmény")
        StatusScreen(
          icon: "heart.text.square", title: "Engedélyezd az Egészség-hozzáférést",
          subtitle: "A pulzus méréséhez szükséges.", buttonTitle: "Beállítások")
      }
    }
  }
#endif

#if DEBUG
  struct AODGallery: View {
    @Environment(\.watchMetrics) private var metrics
    var body: some View {
      AODReader { isAOD in
        VStack(alignment: .leading, spacing: LifeySpacing.sm) {
          Text(verbatim: LifeyAOD.elapsed(12 * 60 + 34)).lifeyAodNumber(metrics)
          Text(verbatim: LifeyAOD.elapsed(65 * 60 + 10)).lifeyAodNumber(metrics)
          Text(verbatim: LifeyAOD.remaining(59)).foregroundColor(LifeyAOD.numberColor)
          Text(verbatim: LifeyAOD.restUntil(endsAt: Date().addingTimeInterval(60)))
            .foregroundColor(LifeyAOD.numberColor)
          HStack {
            Image(systemName: LifeyAOD.symbol("heart.fill", filled: !isAOD))
              .foregroundColor(isAOD ? LifeyAOD.metricTint(LifeyColors.heart) : LifeyColors.heart)
            Text(verbatim: isAOD ? "AOD" : "full")
          }
        }
        .padding(LifeySpacing.md)
        .background(isAOD ? LifeyColors.bg : LifeyColors.card)
      }
    }
  }
#endif
