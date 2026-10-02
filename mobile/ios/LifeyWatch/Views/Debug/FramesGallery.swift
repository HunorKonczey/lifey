#if DEBUG
  import SwiftUI

  /// Canvas frame fixtures (D-X0.11): each `AWx.y` renders the real content view with a plain model at the
  /// canvas size, so a frame can be compared one-to-one with `docs/redesign-watch/Lifey Watch … .dc.html`.
  /// X1 / X2 steps register their frames in `FrameGallery.all`.
  struct DeviceFrame<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
      content
        .environment(\.watchMetrics, WatchMetrics(width: width))
        .containerShape(RoundedRectangle(cornerRadius: width < 190 ? 38 : 44))
        .frame(width: width, height: height)
        .background(LifeyColors.bg)
        .clipShape(RoundedRectangle(cornerRadius: width < 190 ? 38 : 44))
        .overlay(
          RoundedRectangle(cornerRadius: width < 190 ? 38 : 44).stroke(LifeyColors.outline, lineWidth: 1))
    }
  }

  struct GalleryFrame: Identifiable {
    let id: String
    let title: String
    /// 45 mm (198 × 242) unless `compact`.
    var compact = false
    let content: () -> AnyView

    init<C: View>(_ id: String, _ title: String, compact: Bool = false, @ViewBuilder content: @escaping () -> C) {
      self.id = id
      self.title = title
      self.compact = compact
      self.content = { AnyView(content()) }
    }
  }

  enum FrameGallery {
    static var all: [GalleryFrame] { start + picker2 + errors + standalone + cardio + aod + strength + logging + stepper + rest + controls + picker + finishing + summary }

    static var strength: [GalleryFrame] {
      [
        GalleryFrame("AW1.1", "Metric page") { MetricsContent(model: .fixture()) },
        GalleryFrame("AW1.2", "Paused") { MetricsContent(model: .fixture(paused: true)) },
        GalleryFrame("AW1.3", "No HR · long name") {
          MetricsContent(model: .fixture(hr: nil, name: "Bulgarian Split Squat"))
        },
        GalleryFrame("AW1.4", "Metric page · 41 mm", compact: true) { MetricsContent(model: .fixture()) },
      ]
    }
  }

  extension FrameGallery {
    static var logging: [GalleryFrame] {
      func page(_ state: LogPageState, counter: String = "", chip: Bool = false, compact: Bool = false) -> LogContent {
        LogContent(
          model: LogModel(
            elapsedSeconds: 12 * 60 + 34, contextName: "Fekvenyomás", contextSuffix: " · 3/4 szett", state: state,
            confirmedCounter: counter, canChooseExercise: chip))
      }
      return [
        GalleryFrame("AW1.5", "Log page") { page(.ready) },
        GalleryFrame("AW1.6", "Logging pending") { page(.pending) },
        GalleryFrame("AW1.7", "Set logged") { page(.confirmed, counter: "3/4") },
        GalleryFrame("AW1.8", "Logging failed") { page(.failed) },
        GalleryFrame("AW1.9", "Phone unreachable") { page(.unreachable) },
        GalleryFrame("AW1.12", "Log page · 41 mm · chip", compact: true) { page(.ready, chip: true) },
      ]
    }
  }

  extension FrameGallery {
    static var stepper: [GalleryFrame] {
      [
        GalleryFrame("AW1.10", "Stepper · reps") {
          AdjustContent(model: AdjustModel(field: .reps, valueText: "8", captionText: "ism. · 62,5 kg", confirmText: "8 ismétlés naplózása"))
        },
        GalleryFrame("AW1.11", "Stepper · weight", compact: true) {
          AdjustContent(model: AdjustModel(field: .weight, valueText: "102,5", captionText: "kg · 8 ism.", confirmText: "8 ismétlés naplózása"))
        },
      ]
    }
  }

  extension FrameGallery {
    static var rest: [GalleryFrame] {
      func rest(_ seconds: Int, next: String = "Következő · Fekvenyomás — 3/4. szett") -> RestContent {
        RestContent(model: RestModel(remainingSeconds: seconds, totalSeconds: 90, nextLine: next, heartRateBpm: 112, calories: 87))
      }
      return [
        GalleryFrame("AW1.13", "Rest 0:47") { rest(47) },
        GalleryFrame("AW1.14", "Rest last 5 s") { rest(4) },
        GalleryFrame("AW1.15", "Mehet! rim") {
          ZStack { rest(0); GoFlash() }
        },
        GalleryFrame("AW1.16", "Rest · 41 mm · long name", compact: true) {
          rest(47, next: "Következő · Bulgarian Split Squat — 3/4. szett")
        },
      ]
    }
  }

  extension FrameGallery {
    static var controls: [GalleryFrame] {
      [
        GalleryFrame("AW1.17", "Controls") { ControlsContent(model: ControlsModel(elapsedText: "12:34")) },
        GalleryFrame("AW1.18", "Controls · paused") {
          ControlsContent(model: ControlsModel(elapsedText: "12:34", isPaused: true, canChooseExercise: true))
        },
      ]
    }
  }

  extension FrameGallery {
    static var picker: [GalleryFrame] {
      [
        GalleryFrame("AW1.19", "Exercise picker") {
          ExerciseListContent(rows: [
            ExerciseRowModel(id: 0, name: "Fekvenyomás", setsDone: 3, setsTotal: 4, isCurrent: true),
            ExerciseRowModel(id: 1, name: "Bulgarian Split Squat", setsDone: 1, setsTotal: 3, isCurrent: false),
            ExerciseRowModel(id: 2, name: "Vállnyomás", setsDone: 2, setsTotal: nil, isCurrent: false),
          ])
        },
      ]
    }
  }

  struct EffortFrame: View {
    @State private var rpe = 7
    var body: some View { EffortContent(rpe: $rpe) }
  }

  extension FrameGallery {
    static var finishing: [GalleryFrame] {
      [
        GalleryFrame("AW1.20", "Effort") { EffortFrame() },
        GalleryFrame("AW1.20b", "Effort · 41 mm", compact: true) { EffortFrame() },
        GalleryFrame("AW1.21", "Finish on the iPhone") { EndingContent() },
      ]
    }
  }

  extension FrameGallery {
    static var summary: [GalleryFrame] {
      [
        GalleryFrame("AW1.22", "Summary") {
          SummaryContent(model: SummaryModel(totalSeconds: 2734, averageHeartRate: 128, calories: 312, savedToHealth: true))
        },
      ]
    }
  }

  extension FrameGallery {
    static var start: [GalleryFrame] {
      [
        GalleryFrame("AW2.1", "Idle") { IdleContent() },
        GalleryFrame("AW2.1b", "Idle · 41 mm", compact: true) { IdleContent() },
      ]
    }
  }

  extension FrameGallery {
    static var picker2: [GalleryFrame] {
      let entries: [PickerEntry] = [
        .template(title: "Push nap", exerciseCount: 5), .cardio(activityType: "RUNNING", title: "Futás"),
        .cardio(activityType: "INDOOR_BIKE", title: "Szobakerékpár"),
      ]
      return [
        GalleryFrame("AW2.2", "Picker") { PickerContent(model: PickerModel(entries: entries, hasAllTypes: true)) },
        GalleryFrame("AW2.4", "No synced plans yet") { PickerContent(model: PickerModel(entries: [], hasAllTypes: false)) },
        GalleryFrame("AW2.5", "All activity types") {
          AllTypesContent(entries: [("RUNNING", "Futás"), ("WALKING", "Séta"), ("INDOOR_BIKE", "Szobakerékpár"), ("OTHER_CARDIO", "Egyéb kardió")])
        },
      ]
    }
  }

  extension FrameGallery {
    static var errors: [GalleryFrame] {
      [
        GalleryFrame("AW2.17", "Health access denied") { HealthDeniedContent() },
        GalleryFrame("AW2.18", "Health denied · 41 mm", compact: true) { HealthDeniedContent() },
      ]
    }
  }

  extension FrameGallery {
    static var standalone: [GalleryFrame] {
      [
        GalleryFrame("AW2.6", "Standalone quick strength") {
          MetricsContent(
            model: MetricsModel(
              headerLabel: "Erőedzés", showsStandaloneMark: true, elapsedSeconds: 12 * 60 + 34, heartRateBpm: 121,
              calories: 87, exerciseName: "Gyors erőedzés", freeFormText: "3. szett · összesen 24 ismétlés"))
        },
        GalleryFrame("AW2.7", "Mark tapped") {
          LogContent(
            model: LogModel(
              elapsedSeconds: 12 * 60 + 36, contextName: "Push nap", contextSuffix: " · 3/4 szett",
              showsStandaloneMark: true, markTapped: true))
        },
        GalleryFrame("AW2.9", "Standalone summary · waiting for sync") {
          SummaryContent(model: SummaryModel(
            totalSeconds: 2292, averageHeartRate: 126, calories: 214, setsCount: 9, savedToHealth: true,
            sync: (isSynced: false, pendingCount: 2)))
        },
        GalleryFrame("AW2.10", "Standalone summary · synced") {
          SummaryContent(model: SummaryModel(
            totalSeconds: 2292, averageHeartRate: 126, calories: 214, setsCount: 9, savedToHealth: true,
            sync: (isSynced: true, pendingCount: 1)))
        },
        GalleryFrame("AW2.8", "Standalone log page · chip") {
          LogContent(
            model: LogModel(
              elapsedSeconds: 12 * 60 + 34, contextName: "Fekvenyomás", contextSuffix: " · 3/4 szett",
              canChooseExercise: true, showsStandaloneMark: true))
        },
      ]
    }
  }

  extension FrameGallery {
    static var cardio: [GalleryFrame] {
      let run = CardioModel(
        activityType: "RUNNING", headerLabel: "Futás", primaryLabel: "Távolság", primaryValue: "3.42 km",
        heartRateBpm: 148, fields: [("5:23 /km", "Tempó")])
      let bike = CardioModel(
        activityType: "INDOOR_BIKE", headerLabel: "Szobakerékpár", primaryLabel: "Mozgásidő", primaryValue: "24:10",
        heartRateBpm: 136, fields: [("78 rpm", "Kadencia"), ("165 W", "Átlagos teljesítmény")])
      let field = CardioModel(
        activityType: "BASKETBALL", headerLabel: "Kosárlabda", primaryLabel: "Játékidő", primaryValue: "12:05",
        heartRateBpm: 142, isGame: true, onCourt: true, gross: ("15:40", "Bruttó idő"), toggleTitle: "Padra")
      var bench = field
      bench.onCourt = false; bench.headerLabel = "Padon"; bench.primaryLabel = "Játékidő — áll"
      bench.toggleTitle = "Vissza a pályára"
      var noHr = run
      noHr.heartRateBpm = nil
      return [
        GalleryFrame("AW2.11", "Cardio distance") { CardioContent(model: run) },
        GalleryFrame("AW2.12", "Cardio machine") { CardioContent(model: bike) },
        GalleryFrame("AW2.13", "Team sport · field") { CardioContent(model: field) },
        GalleryFrame("AW2.14", "Team sport · bench") { ZStack { CardioContent(model: bench); BenchFrame() } },
        GalleryFrame("AW2.15", "Cardio without HR") { CardioContent(model: noHr) },
        GalleryFrame("AW2.16", "Team sport · 41 mm", compact: true) { CardioContent(model: field) },
      ]
    }
  }

  extension FrameGallery {
    static var aod: [GalleryFrame] {
      var run = CardioModel(
        activityType: "RUNNING", headerLabel: "Futás", primaryLabel: "Távolság", primaryValue: "3.42 km",
        heartRateBpm: 148, fields: [("5:23 /km", "Tempó")])
      run.primarySeconds = nil
      var bench = CardioModel(
        activityType: "BASKETBALL", headerLabel: "Padon", primaryLabel: "Játékidő — áll", primaryValue: "12:05",
        heartRateBpm: 96, isGame: true, onCourt: false, gross: ("16:00", "Bruttó idő"), toggleTitle: "Vissza a pályára")
      bench.primarySeconds = 12 * 60 + 5
      bench.grossSeconds = 16 * 60
      return [
        GalleryFrame("AW2.20", "AOD metric page") { MetricsContent(model: .fixture(), isAOD: true) },
        GalleryFrame("AW2.21", "AOD rest") {
          RestContent(
            model: RestModel(
              remainingSeconds: 59, totalSeconds: 90, nextLine: "Következő · Fekvenyomás — 3/4. szett",
              endsAt: Date().addingTimeInterval(59)),
            isAOD: true)
        },
        GalleryFrame("AW2.22", "AOD cardio") { CardioContent(model: run, isAOD: true) },
        GalleryFrame("AW2.23", "AOD bench") { CardioContent(model: bench, isAOD: true) },
      ]
    }
  }

  extension MetricsModel {
    static func fixture(
      paused: Bool = false, hr: Int? = 121, name: String = "Fekvenyomás", done: Int = 2, total: Int = 4
    ) -> MetricsModel {
      MetricsModel(
        headerLabel: "Erőedzés", isPaused: paused, elapsedSeconds: 12 * 60 + 34, heartRateBpm: hr,
        calories: 87, exerciseName: name, setsDone: done, setsTotal: total)
    }
  }

  struct FramesGallery: View {
    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.lg) {
        ForEach(FrameGallery.all) { frame in
          VStack(alignment: .leading, spacing: LifeySpacing.xs) {
            Text(verbatim: "\(frame.id) · \(frame.title)")
              .font(.system(size: 10, design: .monospaced))
              .foregroundColor(LifeyColors.text3)
            DeviceFrame(width: frame.compact ? 176 : 198, height: frame.compact ? 215 : 242) {
              frame.content()
            }
          }
        }
      }
    }
  }
#endif
