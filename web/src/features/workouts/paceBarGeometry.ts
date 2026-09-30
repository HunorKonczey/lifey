/**
 * Per-split pace bar geometry — a straight port of the mobile
 * `PaceBarGeometry` (`shared/widgets/charts/pace_bar_chart.dart`), kept as
 * plain arithmetic (no DOM/Canvas) so the two rules that would otherwise fail
 * silently — **taller = faster**, and the partial tail staying out of the
 * scale — are unit-testable directly, same reasoning as the Dart original's
 * doc comment.
 */

export interface PaceBar {
  durationSeconds: number;
  /** Pre-formatted duration ("5:23") — only the caller knows the unit system. */
  label: string;
  /**
   * The run's last, sub-kilometer piece. Drawn, but **excluded from the
   * evaluation**: not scored, scaled, labelled, or averaged. Its duration is
   * short simply because its distance is, so letting it into the scale would
   * crown it the fastest split of the run.
   */
  partial: boolean;
  /**
   * The split's own length. When known, the partial tail is drawn in proportion to it (W3.10: a 200 m tail is a
   * fifth of a kilometre's bar, not a fixed stub); when not, it keeps the old flat stub.
   */
  distanceMeters?: number;
  /** The kilometre count shown over the partial tail ("0,2") — only the caller knows the locale. */
  partialLabel?: string;
}

/** One Y-axis label: a pace and where it sits. */
export interface AxisTick {
  seconds: number;
  y: number;
}

export interface BarRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

const LABEL_BAND = 16;
const MAX_BAR_WIDTH = 26;
const DENSE_BAR_WIDTH = 14;
/** The partial tail is drawn short and flat — it carries no comparable pace. */
const PARTIAL_HEIGHT_FRACTION = 0.22;

export class PaceBarGeometry {
  constructor(
    private readonly bars: PaceBar[],
    private readonly width: number,
    private readonly height: number,
  ) {}

  private get slotWidth(): number {
    return this.bars.length === 0 ? 0 : this.width / this.bars.length;
  }

  /** M33's bar width, and the narrower one it falls back to from 15 splits up. */
  get barWidth(): number {
    const target = this.bars.length >= 15 ? DENSE_BAR_WIDTH : MAX_BAR_WIDTH;
    return Math.min(target, Math.max(4, this.slotWidth - 4));
  }

  /** The bars that count: everything but the partial tail. */
  private get scored(): PaceBar[] {
    return this.bars.filter((b) => !b.partial);
  }

  get slowestSeconds(): number | null {
    const scored = this.scored;
    return scored.length === 0 ? null : Math.max(...scored.map((b) => b.durationSeconds));
  }

  get fastestSeconds(): number | null {
    const scored = this.scored;
    return scored.length === 0 ? null : Math.min(...scored.map((b) => b.durationSeconds));
  }

  /** The index of the single fastest scored bar — the only one that gets a value label. */
  get fastestIndex(): number | null {
    let best: number | null = null;
    for (let i = 0; i < this.bars.length; i++) {
      if (this.bars[i].partial) continue;
      if (best === null || this.bars[i].durationSeconds < this.bars[best].durationSeconds) best = i;
    }
    return best;
  }

  /**
   * Maps a duration to a 0..1 bar height, inverted so the *quickest* split is
   * the *tallest* bar. A run of identical splits has no span to spread over,
   * so every bar lands on the same mid-height rather than dividing by zero or
   * all shooting to full height.
   */
  private heightFractionFor(seconds: number): number {
    const slowest = this.slowestSeconds;
    const fastest = this.fastestSeconds;
    if (slowest == null || fastest == null) return 0.5;
    const span = slowest - fastest;
    if (span <= 0) return 0.72;
    const speed = Math.min(1, Math.max(0, (slowest - seconds) / span));
    return 0.35 + 0.65 * speed;
  }

  private get plotHeight(): number {
    return Math.max(0, this.height - LABEL_BAND);
  }

  /** The mean of the scored durations, or null when nothing is scored. */
  get averageSeconds(): number | null {
    const scored = this.scored;
    return scored.length === 0 ? null : scored.reduce((sum, b) => sum + b.durationSeconds, 0) / scored.length;
  }

  /**
   * A partial tail in proportion to its length: the height an average full kilometre has, times the share of a
   * kilometre it covers (never thinner than a visible sliver). Flat stub when its length is unknown.
   */
  private partialFraction(bar: PaceBar): number {
    const mean = this.averageSeconds;
    if (bar.distanceMeters == null || mean == null) return PARTIAL_HEIGHT_FRACTION;
    const share = Math.min(1, Math.max(0, bar.distanceMeters / 1000));
    return Math.max(0.06, this.heightFractionFor(Math.round(mean)) * share);
  }

  /**
   * Y-axis labels (5:30 / 6:00 / 6:30): multiples of 30 s inside the scored range, thinned to at most three.
   * Empty when there is no range to label (one scored bar, or identical splits).
   */
  axisTicks(): AxisTick[] {
    const fastest = this.fastestSeconds;
    const slowest = this.slowestSeconds;
    if (fastest == null || slowest == null || slowest <= fastest) return [];
    let step = 30;
    const ticksFor = (s: number) => {
      const out: number[] = [];
      for (let t = Math.ceil(fastest / s) * s; t <= slowest; t += s) out.push(t);
      return out;
    };
    let seconds = ticksFor(step);
    while (seconds.length > 3 && step < 600) {
      step *= 2;
      seconds = ticksFor(step);
    }
    return seconds.map((s) => ({ seconds: s, y: this.height - this.plotHeight * this.heightFractionFor(s) }));
  }

  barRect(index: number): BarRect {
    const bar = this.bars[index];
    const fraction = bar.partial ? this.partialFraction(bar) : this.heightFractionFor(bar.durationSeconds);
    const barHeight = this.plotHeight * fraction;
    const x = index * this.slotWidth + (this.slotWidth - this.barWidth) / 2;
    return { x, y: this.height - barHeight, width: this.barWidth, height: barHeight };
  }

  /** The dashed reference line's Y, at the mean of the scored durations. */
  get averageLineY(): number | null {
    const scored = this.scored;
    if (scored.length === 0) return null;
    const mean = scored.reduce((sum, b) => sum + b.durationSeconds, 0) / scored.length;
    const fraction = this.heightFractionFor(Math.round(mean));
    return this.height - this.plotHeight * fraction;
  }

  indexAt(x: number): number | null {
    if (this.bars.length === 0 || this.slotWidth <= 0) return null;
    const index = Math.floor(x / this.slotWidth);
    if (index < 0 || index >= this.bars.length) return null;
    return index;
  }
}
