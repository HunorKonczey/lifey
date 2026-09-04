import { ValueSection } from "../home/ValueSection";

/**
 * Wraps the home page's ValueSection (65 Prompt 4) for this page's six
 * blocks (68 §13.1: "the same section vocabulary as the home page's
 * 4.4–4.6, expanded to six blocks... no new components"). Adds one thing
 * ValueSection's own callers (ClientsSection etc.) don't need generically:
 * a shared mobile fallback. Those three callers each hand-build a bespoke
 * compact mobile visual per block; doing that six times for a page with no
 * design frame to check the result against would be inventing six more
 * unreviewed layouts. This renders copy only on mobile — eyebrow, title,
 * body, bullets — which still satisfies 68 §4.4's "copy before visual"
 * rule, just without a visual.
 */
export function TrainerValueBlock({
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
    <>
      <ValueSection
        eyebrow={eyebrow}
        title={title}
        body={body}
        bullets={bullets}
        visual={visual}
        imageSide={imageSide}
        background={background}
      />

      <section
        className="md:hidden py-9 px-4"
        style={{ background: background === "bg" ? "var(--bg)" : "var(--surface-container)" }}
      >
        <div className="text-[11px] font-extrabold tracking-wide" style={{ color: "var(--primary)" }}>
          {eyebrow.toUpperCase()}
        </div>
        <h2 className="text-[24px] font-bold tracking-[-0.02em] leading-[1.16] mt-2.5">{title}</h2>
        <p className="text-[15px] leading-[1.55] mt-3" style={{ color: "var(--on-surface-variant)" }}>
          {body}
        </p>
        <ul className="flex flex-col gap-2 mt-4">
          {bullets.map((b) => (
            <li key={b} className="flex gap-2.5 items-start">
              <span
                className="material-symbols-rounded text-lg mt-0.5"
                style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}
              >
                check_circle
              </span>
              <span className="text-[13.5px]">{b}</span>
            </li>
          ))}
        </ul>
      </section>
    </>
  );
}
