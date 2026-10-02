#if DEBUG
  import SwiftUI

  /// DEBUG-only design gallery (D-X0.11): every token, type style and component in every state, at the two
  /// reference sizes, plus a "Frames" section of canvas fixtures. Opened by a long-press on the idle leaf
  /// (`IdleView`); it does not exist in Release builds.
  ///
  /// Later steps add their component sections to `sections` — one `GallerySection` per design-system frame
  /// 04 component, then the AW fixtures under "Frames".
  struct DesignGalleryView: View {
    /// The reference dial widths (45 mm, 41 mm). The chosen one is rendered as a fixed-width column so
    /// the 176 pt layout can be checked on a 198 pt simulator.
    private static let widths: [CGFloat] = [WatchMetrics.regularReferenceWidth, WatchMetrics.compactReferenceWidth]

    @State private var widthIndex = 0
    @State private var aod = false

    private var width: CGFloat { Self.widths[widthIndex] }

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: LifeySpacing.lg) {
          header
          ForEach(GallerySection.all) { section in
            VStack(alignment: .leading, spacing: LifeySpacing.sm) {
              Text(section.title)
                .font(.caption2.bold())
                .foregroundColor(LifeyColors.text2)
              section.content()
            }
          }
        }
        .frame(width: width, alignment: .leading)
        .environment(\.watchMetrics, WatchMetrics(width: width))
        .environment(\.galleryAOD, aod)
        .padding(.vertical, LifeySpacing.md)
      }
      .background(LifeyColors.bg)
      .navigationTitle("Gallery")
    }

    private var header: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.xs) {
        Button("\(Int(width)) pt · \(WatchMetrics(width: width).isCompact ? "compact" : "regular")") {
          widthIndex = (widthIndex + 1) % Self.widths.count
        }
        Toggle("AOD", isOn: $aod)
      }
    }
  }

  /// Forces the reduced-luminance look inside the gallery (X0a.11 reads this).
  private struct GalleryAODKey: EnvironmentKey { static let defaultValue = false }
  extension EnvironmentValues {
    var galleryAOD: Bool {
      get { self[GalleryAODKey.self] }
      set { self[GalleryAODKey.self] = newValue }
    }
  }

  struct GallerySection: Identifiable {
    let id: String
    let title: String
    let content: () -> AnyView

    init<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) {
      self.id = title
      self.title = title
      self.content = { AnyView(content()) }
    }

    /// Registry — later steps append their sections here.
    static var all: [GallerySection] {
      [
        GallerySection("01 Tokens") { TokenSwatches() },
        GallerySection("02 Type") { TypeRamp() },
        GallerySection("03 Metrics") { MetricsReadout() },
        GallerySection("04/01 Header chip") { HeaderChipGallery() },
        GallerySection("04/02 Metric reading") { MetricReadingGallery() },
        GallerySection("04/03 Set segment bar") { SegmentBarGallery() },
        GallerySection("04/02 Heart-rate slot") { HeartRateSlotGallery() },
        GallerySection("04/04 Circle button") { CircleButtonGallery() },
        GallerySection("04/05 Status pill") { StatusPillGallery() },
      ]
    }
  }

  private struct TokenSwatches: View {
    private let swatches: [(String, Color)] = [
      ("bg", LifeyColors.bg), ("card", LifeyColors.card), ("nested", LifeyColors.nested),
      ("control", LifeyColors.control), ("raised", LifeyColors.raised), ("outline", LifeyColors.outline),
      ("text", LifeyColors.text), ("text2", LifeyColors.text2), ("text3", LifeyColors.text3),
      ("ghost", LifeyColors.ghost), ("primary", LifeyColors.primary), ("heart", LifeyColors.heart),
      ("calories", LifeyColors.calories), ("success", LifeyColors.success), ("clay", LifeyColors.clay),
    ]

    var body: some View {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: LifeySpacing.xs)], spacing: LifeySpacing.xs) {
        ForEach(swatches, id: \.0) { name, color in
          VStack(spacing: LifeySpacing.xxs) {
            RoundedRectangle(cornerRadius: LifeyShapes.tag)
              .fill(color)
              .frame(height: 24)
              .overlay(RoundedRectangle(cornerRadius: LifeyShapes.tag).stroke(LifeyColors.outline, lineWidth: 0.5))
            Text(name).font(.system(size: 9)).foregroundColor(LifeyColors.text2)
          }
        }
      }
    }
  }

  private struct TypeRamp: View {
    @Environment(\.watchMetrics) private var metrics

    var body: some View {
      VStack(alignment: .leading, spacing: LifeySpacing.xs) {
        Text("12:34").lifeyHero(metrics).foregroundColor(LifeyColors.text)
        LifeyNumber(number: "128", unit: "bpm", style: .metric, color: LifeyColors.heart)
        LifeyNumber(number: "62,5", unit: "kg", style: .value)
        Text("Cím").lifeyTitle(metrics).foregroundColor(LifeyColors.text)
        Text("Törzsszöveg").lifeyBody(metrics).foregroundColor(LifeyColors.text)
        Text("Címke").lifeyLabel(metrics, caps: true).foregroundColor(LifeyColors.text2)
      }
    }
  }

  private struct MetricsReadout: View {
    @Environment(\.watchMetrics) private var metrics

    var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        row("hero", metrics.hero)
        row("hero dense", metrics.heroDense)
        row("metric", metrics.metric)
        row("value", metrics.value)
        row("circle", metrics.circleButton)
        row("button", metrics.buttonHeight)
        row("touch", metrics.minTouchTarget)
        row("margin", metrics.sideMargin)
      }
      .font(.system(size: 11).monospacedDigit())
      .foregroundColor(LifeyColors.text2)
    }

    private func row(_ name: String, _ value: CGFloat) -> some View {
      HStack { Text(name); Spacer(); Text("\(Int(value))") }
    }
  }

  #Preview("Gallery 45 mm") { NavigationStack { DesignGalleryView() } }
#endif
