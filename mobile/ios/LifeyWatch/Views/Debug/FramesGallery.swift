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
    static var all: [GalleryFrame] { strength + logging + stepper }

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
