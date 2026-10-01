import { Icon } from "../../Icon";

const SAMPLE_ICONS = ["space_dashboard", "restaurant", "fitness_center", "monitor_weight", "water_drop", "bar_chart"];

/** D-W0.10 — FILL 0 (inactive) vs FILL 1 (active) through the one `Icon`
 *  component, the shape a nav item switches on selection (DS-02). */
export function IconsSection() {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap gap-6">
        {SAMPLE_ICONS.map((name) => (
          <div key={name} className="flex flex-col items-center gap-2">
            <div className="flex gap-2">
              <Icon name={name} fill={0} size={28} label={`${name}, outline`} />
              <Icon name={name} fill={1} size={28} label={`${name}, filled`} />
            </div>
            <code className="type-label" style={{ color: "var(--text-3)" }}>{name}</code>
          </div>
        ))}
      </div>
      <div className="flex items-center gap-2">
        {[100, 300, 400, 500, 700].map((weight) => (
          <Icon key={weight} name="star" weight={weight} size={28} label={`weight ${weight}`} />
        ))}
      </div>
    </div>
  );
}
