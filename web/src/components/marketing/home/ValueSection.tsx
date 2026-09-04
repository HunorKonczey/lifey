/**
 * The 6/6 alternating layout shared by §4.4–§4.6 (design/Lifey Landing.dc.html
 * L10/L11/L12) — screenshot on one side, copy on the other, desktop only.
 * Mobile always puts copy first (68 §4.4); see HomeMobileSections.tsx for the
 * mobile rendering of the same content (L15), which does not reuse this
 * component since the mobile layout is a single column regardless of side.
 */
export function ValueSection({
  eyebrow,
  title,
  body,
  bullets,
  visual,
  imageSide,
  background,
}: {
  eyebrow: string;
  title: string;
  body: string;
  bullets: string[];
  visual: React.ReactNode;
  imageSide: "left" | "right";
  background: "bg" | "container";
}) {
  return (
    <section
      className="hidden md:block py-24"
      style={{ background: background === "bg" ? "var(--bg)" : "var(--surface-container)" }}
    >
      <div
        className="max-w-[1200px] mx-auto px-8 grid gap-14 items-center"
        style={{ gridTemplateColumns: imageSide === "right" ? "5fr 7fr" : "7fr 5fr" }}
      >
        {imageSide === "left" && <div>{visual}</div>}
        <div>
          <div className="text-xs font-extrabold tracking-wide" style={{ color: "var(--primary)" }}>
            {eyebrow.toUpperCase()}
          </div>
          <h2 className="text-[44px] font-bold tracking-[-0.02em] leading-[1.1] mt-3.5">{title}</h2>
          <p className="text-xl font-medium leading-[1.6] mt-4.5" style={{ color: "var(--on-surface-variant)" }}>
            {body}
          </p>
          <ul className="flex flex-col gap-3 mt-6.5">
            {bullets.map((b) => (
              <li key={b} className="flex gap-3 items-start">
                <span
                  className="material-symbols-rounded text-xl mt-0.5"
                  style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}
                >
                  check_circle
                </span>
                <span className="text-base">{b}</span>
              </li>
            ))}
          </ul>
        </div>
        {imageSide === "right" && <div>{visual}</div>}
      </div>
    </section>
  );
}
