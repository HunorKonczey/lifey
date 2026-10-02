import SwiftUI

// MARK: - Idle (redesign X2.1 — AW2.1)

/// No active session — the launcher. The leaf in a `card` holder (primary glyph), "Lifey" in PJS 800 (the
/// one place PJS carries letters — the ExtraBold subset covers L i f e y), a full-width 48 pt primary
/// start button on one line, and the quiet "or start it on the phone" caption in `text2`. Opens
/// `StandalonePickerView` (docs/watch/44-watch-f6-standalone-plan.md §3.1).
struct IdleContent: View {
  var onStart: () -> Void = {}
  #if DEBUG
    var onLeafLongPress: () -> Void = {}
  #endif

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    VStack(spacing: LifeySpacing.md) {
      Spacer(minLength: 0)
      leaf
      Text(verbatim: "Lifey")
        .font(.custom(LifeyFont.extraBold, fixedSize: metrics.isCompact ? 22 : 26))
        .foregroundColor(LifeyColors.text)
      Button(action: onStart) {
        Text("standalone_start_button")
          .lifeyBodyBold(metrics)
          .foregroundColor(LifeyColors.onPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
          .frame(maxWidth: .infinity, minHeight: metrics.buttonHeight)
          .background(LifeyColors.primary, in: Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text("standalone_start_button_a11y"))
      Text("standalone_start_caption")
        .lifeyLabel(metrics)
        .foregroundColor(LifeyColors.text2)
        .multilineTextAlignment(.center)
        .lineLimit(2)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, metrics.sideMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var leaf: some View {
    let holder: CGFloat = metrics.isCompact ? 40 : 46
    let view = ZStack {
      RoundedRectangle(cornerRadius: LifeyShapes.control)
        .fill(LifeyColors.card)
        .frame(width: holder, height: holder)
      Image(systemName: "leaf.fill")
        .font(.system(size: holder * 0.5))
        .foregroundColor(LifeyColors.primary)
    }
    #if DEBUG
      return view.onLongPressGesture(perform: onLeafLongPress)  // design gallery, Debug builds only
    #else
      return view
    #endif
  }
}

struct IdleView: View {
  let onStartTapped: () -> Void
  #if DEBUG
    @State private var showGallery = false
  #endif

  var body: some View {
    #if DEBUG
      IdleContent(onStart: onStartTapped, onLeafLongPress: { showGallery = true })
        .background(LifeyColors.bg)
        .sheet(isPresented: $showGallery) { NavigationStack { DesignGalleryView() } }
    #else
      IdleContent(onStart: onStartTapped).background(LifeyColors.bg)
    #endif
  }
}

#Preview {
  IdleView(onStartTapped: {})
}
