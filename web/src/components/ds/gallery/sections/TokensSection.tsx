const RADII = [
  { label: "r-tag", varName: "--r-tag" },
  { label: "r-control", varName: "--r-control" },
  { label: "r-card", varName: "--r-card" },
  { label: "r-hero", varName: "--r-hero" },
  { label: "r-pill", varName: "--r-pill" },
];

const SPACING = [16, 20, 24, 32];

const ELEVATIONS = [
  { label: "e1 (card)", varName: "--e1", edge: "--edge-card" },
  { label: "e2 (hero, FAB)", varName: "--e2", edge: "--edge-hero" },
  { label: "e3 (float)", varName: "--e3", edge: "--edge-float" },
];

/** D-W0.5 radius scale, the D-W0.6 spacing values in prose, and the D-W0.2
 *  elevation ladder — one section since none needs live-value plumbing
 *  beyond a plain `var(...)` reference. */
export function TokensSection() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h3 className="type-section mb-2">Radius (4 steps + pill)</h3>
        <div className="flex flex-wrap gap-4">
          {RADII.map((r) => (
            <div key={r.label} className="flex flex-col items-center gap-2">
              <div
                className="w-16 h-16"
                style={{ background: "var(--control)", borderRadius: `var(${r.varName})` }}
              />
              <code className="type-label" style={{ color: "var(--text-3)" }}>{r.label}</code>
            </div>
          ))}
        </div>
      </div>

      <div>
        <h3 className="type-section mb-2">Spacing</h3>
        <div className="flex items-end gap-3">
          {SPACING.map((px) => (
            <div key={px} className="flex flex-col items-center gap-2">
              <div style={{ width: px, height: px, background: "var(--primary)", borderRadius: 4 }} />
              <code className="type-label" style={{ color: "var(--text-3)" }}>{px}</code>
            </div>
          ))}
        </div>
      </div>

      <div>
        <h3 className="type-section mb-2">Elevation</h3>
        <div className="flex flex-wrap gap-6">
          {ELEVATIONS.map((e) => (
            <div
              key={e.label}
              className="w-32 h-20 flex items-end p-2 type-label"
              style={{
                background: "var(--card)",
                borderRadius: "var(--r-card)",
                boxShadow: `var(${e.varName}), var(${e.edge})`,
                color: "var(--text-3)",
              }}
            >
              {e.label}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
