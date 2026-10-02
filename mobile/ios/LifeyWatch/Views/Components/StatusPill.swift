import SwiftUI

/// Status pill (frame 04/05): 28 pt, icon + one line; wraps to two lines left-aligned with radius 22 when
/// the text needs it. One pill at a time — see `Kind.priority`.
struct StatusPill: View {
  enum Kind: CaseIterable {
    case logged  // success tint
    case pending  // nested + hourglass
    case failed  // error tint + icon
    case unreachable  // nested + text2
    case handoff  // nested (AW2.7: "Folytatás a telefonon…")

    /// Failed › unreachable › pending › logged; handoff stands alone (standalone mark tap).
    var priority: Int {
      switch self {
      case .failed: return 4
      case .unreachable: return 3
      case .pending: return 2
      case .logged: return 1
      case .handoff: return 0
      }
    }

    var icon: String {
      switch self {
      case .logged: return "checkmark"
      case .pending: return "hourglass"
      case .failed: return "exclamationmark.triangle.fill"
      case .unreachable: return "iphone.slash"
      case .handoff: return "arrow.triangle.2.circlepath"
      }
    }

    var background: Color {
      switch self {
      case .logged: return LifeyColors.tint(LifeyColors.success)
      case .failed: return LifeyColors.tint(LifeyColors.error)
      case .pending, .unreachable, .handoff: return LifeyColors.nested
      }
    }

    var content: Color {
      switch self {
      case .logged: return LifeyColors.success
      case .failed: return LifeyColors.error
      case .pending: return LifeyColors.text
      case .unreachable, .handoff: return LifeyColors.text2
      }
    }
  }

  /// The pill to show out of several simultaneous states: the highest priority wins.
  static func winner(of kinds: [Kind]) -> Kind? {
    kinds.max(by: { $0.priority < $1.priority })
  }

  let kind: Kind
  let text: String

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    HStack(alignment: .top, spacing: LifeySpacing.xs) {
      Image(systemName: kind.icon)
        .font(.system(size: metrics.isCompact ? 12 : 13, weight: .bold))
        .padding(.top, 1)
      Text(verbatim: text)
        .lifeyBody(metrics)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
    }
    .foregroundColor(kind.content)
    .padding(.horizontal, LifeySpacing.lg)
    .padding(.vertical, LifeySpacing.xs)
    .frame(minHeight: 28)
    .background(kind.background, in: RoundedRectangle(cornerRadius: pillRadius))
  }

  /// A full capsule for one line, the card radius (22) once it wraps to two.
  private var pillRadius: CGFloat { LifeyShapes.card }
}
