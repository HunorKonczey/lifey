import { Card } from "../../Card";
import { SectionLabel } from "../../SectionLabel";

/** D-W0.7 — the three card variants, plus an interactive one, and SectionLabel. */
export function CardsSection() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <SectionLabel action={{ label: "Mind" }}>Section label</SectionLabel>
      </div>
      <div className="flex flex-wrap gap-4">
        <Card variant="card" style={{ width: 220 }}>
          <p className="type-title-s">card</p>
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>r22 · e1 in light, edge in dark</p>
        </Card>
        <Card variant="hero" style={{ width: 220 }}>
          <p className="type-title-s">hero</p>
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>r30 · e2</p>
        </Card>
        <Card variant="card" interactive style={{ width: 220 }}>
          <p className="type-title-s">card, interactive</p>
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>hover + press 0.98</p>
          <Card variant="nested" className="mt-3">
            <p className="type-body-s">nested row</p>
          </Card>
        </Card>
      </div>
    </div>
  );
}
