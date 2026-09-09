/**
 * Shared layout for the four legal pages (docs/landing_page/65 Prompt 8, 68
 * §6: "one column, 62 ch... a sticky table of contents on desktop. Print
 * stylesheet: no header, no footer, black on white."). One component
 * instead of four copies since the layout is identical — only the content
 * differs per document.
 *
 * The print stylesheet targets the header/footer/sticky-CTA by the stable
 * selectors they already expose (`<header>`, `#site-footer`) — plus a new
 * `#mobile-sticky-cta` id added to MobileStickyCta.tsx specifically so this
 * component has something to hide it by by; it had none before.
 */
export function LegalDocument({
  title,
  updated,
  sections,
}: {
  title: string;
  updated: string;
  /** `body` is plain text; a newline starts a new paragraph/line. */
  sections: { id: string; heading: string; body: string }[];
}) {
  return (
    <main className="py-14 md:py-20" style={{ background: "var(--bg)" }}>
      <style>{`
        @media print {
          header, #site-footer, #mobile-sticky-cta, .legal-toc { display: none !important; }
          main, body, section, article { background: #fff !important; color: #000 !important; }
          h1, h2, p, li { color: #000 !important; }
        }
      `}</style>

      <div className="max-w-[1000px] mx-auto px-4 md:px-8">
        <h1 className="text-[32px] md:text-[44px] font-bold tracking-[-0.02em]">{title}</h1>
        <p className="text-sm mt-2" style={{ color: "var(--muted)" }}>
          {updated}
        </p>

        <div className="grid md:grid-cols-[220px_1fr] gap-8 md:gap-12 mt-8 md:mt-10">
          <nav className="legal-toc hidden md:block" aria-label={title}>
            <div className="sticky top-24 flex flex-col gap-1">
              {sections.map((s) => (
                <a
                  key={s.id}
                  href={`#${s.id}`}
                  className="text-sm font-bold py-1.5 border-l-2 pl-3.5"
                  style={{ borderColor: "var(--outline)", color: "var(--on-surface-variant)" }}
                >
                  {s.heading}
                </a>
              ))}
            </div>
          </nav>

          <article className="max-w-[62ch]">
            {sections.map((s) => (
              <section key={s.id} id={s.id} className="scroll-mt-24 mb-8">
                <h2 className="text-lg md:text-xl font-bold">{s.heading}</h2>
                <div
                  className="text-base leading-[1.7] mt-3 flex flex-col gap-3"
                  style={{ color: "var(--on-surface-variant)" }}
                >
                  {s.body.split("\n").map((line, i) => (
                    <p key={i}>{line}</p>
                  ))}
                </div>
              </section>
            ))}
          </article>
        </div>
      </div>
    </main>
  );
}
