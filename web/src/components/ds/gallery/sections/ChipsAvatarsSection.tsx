import { Card } from "../../Card";
import { TintedChip } from "../../TintedChip";
import { RecordChip } from "../../RecordChip";
import { ImprovementChip } from "../../ImprovementChip";
import { DeltaChip } from "../../DeltaChip";
import { Avatar } from "../../Avatar";
import { CountPill } from "../../CountPill";

const METRICS = [
  { label: "kcal", varName: "--m-kcal" },
  { label: "protein", varName: "--m-protein" },
  { label: "carbs", varName: "--m-carbs" },
  { label: "fat", varName: "--m-fat" },
  { label: "water", varName: "--m-water" },
  { label: "steps", varName: "--m-steps" },
  { label: "weight", varName: "--m-weight" },
];

/**
 * D-W0.7 — TintedChip per metric, RecordChip/ImprovementChip, DeltaChip's
 * goal-aware colouring (W4 note), Avatar (monogram + role rings), CountPill.
 *
 * Wrapped in a `Card`, not floating on the page's bare `--bg`: a chip's tint
 * is translucent by design (D-W0.4), so it composites against whatever's
 * behind it — on `--card` that clears AA with room to spare, but directly on
 * `--bg` (a warmer, slightly darker cream) axe caught two metrics dropping
 * just under 4.5:1. Every real call site places chips inside a card anyway
 * (the design system's own "fewer boxes" principle), so this section now
 * matches that rather than the accidentally-harder bare-page case.
 */
export function ChipsAvatarsSection() {
  return (
    <Card className="flex flex-col gap-6">
      <div>
        <h3 className="type-section mb-2">Tinted chips</h3>
        <div className="flex flex-wrap gap-2">
          {METRICS.map((m) => (
            <TintedChip key={m.label} label={m.label} color={`var(${m.varName})`} />
          ))}
          <RecordChip label="🏆 PR" />
          <ImprovementChip label="↑ 12g" />
        </div>
      </div>

      <div>
        <h3 className="type-section mb-2">Delta chip (goal-aware, W4 note)</h3>
        <div className="flex flex-wrap gap-2">
          <DeltaChip value={-0.4} unit="kg" goalDirection="lower" />
          <DeltaChip value={0.4} unit="kg" goalDirection="lower" />
          <DeltaChip value={0} unit="kg" goalDirection="lower" />
          <DeltaChip value={1200} digits={0} goalDirection="higher" />
          <DeltaChip value={-3} digits={0} />
        </div>
      </div>

      <div>
        <h3 className="type-section mb-2">Avatars</h3>
        <div className="flex items-center gap-3">
          <Avatar name="Anna Kovács" size={44} />
          <Avatar name="Szabó Bence" color="var(--m-water)" size={44} />
          <Avatar email="nagy.kata@example.com" size={44} />
          <Avatar name="Szabó Bence" color="var(--m-water)" size={44} roleRing="trainer" />
          <Avatar name="Admin User" size={44} roleRing="superadmin" />
        </div>
      </div>

      <div>
        <h3 className="type-section mb-2">Count pill</h3>
        <div className="flex items-center gap-3">
          <CountPill count={3} />
          <CountPill count={128} />
          <CountPill count={0} />
          <span className="type-body-s" style={{ color: "var(--text-3)" }}>(0 renders nothing)</span>
        </div>
      </div>
    </Card>
  );
}
