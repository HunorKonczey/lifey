/**
 * The "browser window" chrome (three dots + a URL bar) wrapping the /admin
 * mockups reused across the hero, "Minden kliensed egy helyen" and
 * "Programot írsz, nem táblázatot" sections (design/Lifey Landing.dc.html,
 * L04/L05/L10/L11). Built from the same tokens as the real app, so it
 * themes correctly without a second, hardcoded light-mode colour set
 * (68 §12's DV note on this file's own reasoning applies here too).
 */
export function BrowserWindowFrame({
  url,
  children,
}: {
  url: string;
  children: React.ReactNode;
}) {
  return (
    <div
      className="rounded-lg overflow-hidden border border-outline"
      style={{ background: "var(--surface)", boxShadow: "var(--shadow-float), 0 24px 60px rgba(0,0,0,.25)" }}
    >
      <div
        className="h-[34px] flex items-center gap-1.5 px-3 border-b border-outline"
        style={{ background: "var(--surface-container)" }}
      >
        <span className="w-2.5 h-2.5 rounded-full" style={{ background: "var(--outline)" }} />
        <span className="w-2.5 h-2.5 rounded-full" style={{ background: "var(--outline)" }} />
        <span className="w-2.5 h-2.5 rounded-full" style={{ background: "var(--outline)" }} />
        <div
          className="ml-2.5 h-5 flex-1 rounded-pill flex items-center px-2.5 text-[10px]"
          style={{ background: "var(--bg)", color: "var(--muted)" }}
        >
          {url}
        </div>
      </div>
      {children}
    </div>
  );
}
