const SCALE = [
  "type-display-xl",
  "type-display",
  "type-headline",
  "type-page",
  "type-title-l",
  "type-title",
  "type-title-s",
  "type-body",
  "type-body-s",
  "type-section",
  "type-label",
  "type-button",
  "type-table-head",
] as const;

/** D-W0.7 — every `type-*` utility against the longest Hungarian sample the
 *  canvases use, so a scale that overflows shows it here first. Label above
 *  sample (not side by side): at 72px a single Hungarian word can be wider
 *  than a 390px gallery column even after wrapping, so this stacks instead
 *  of fighting for horizontal room. */
export function TypeSection() {
  return (
    <div className="flex flex-col gap-5">
      {SCALE.map((cls) => (
        <div key={cls}>
          <code className="type-label block mb-1" style={{ color: "var(--text-3)" }}>
            {cls}
          </code>
          <div className={cls} style={{ overflowWrap: "break-word" }}>
            Ételeim &amp; receptjeim 69,6 kg
          </div>
        </div>
      ))}
      <div>
        <code className="type-label block mb-1" style={{ color: "var(--text-3)" }}>.num (hero)</code>
        <div className="num" style={{ fontSize: 56 }}>859</div>
      </div>
    </div>
  );
}
