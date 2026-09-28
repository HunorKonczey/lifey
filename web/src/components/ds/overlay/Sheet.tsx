import { forwardRef, type ReactNode } from "react";

export interface SheetProps {
  onScrimClick: () => void;
  "aria-label"?: string;
  children: ReactNode;
}

/** The <768px shape of `Modal` (D-W0.12): slides up from the bottom, a
 *  36×4 handle, radius 30 on the top corners only, 350ms
 *  (`--dur-sheet`), safe-area aware for a phone's home indicator. */
export const Sheet = forwardRef<HTMLDivElement, SheetProps>(function Sheet(
  { onScrimClick, children, ...aria },
  ref,
) {
  return (
    <div
      className="fixed inset-0 z-[60] flex items-end"
      style={{ background: "var(--modal-scrim)", animation: "lifey-scrim-enter var(--dur-sheet) var(--ease-standard)" }}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onScrimClick();
      }}
    >
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label={aria["aria-label"]}
        tabIndex={-1}
        className="w-full overflow-y-auto"
        style={{
          maxHeight: "85vh",
          background: "var(--modal-bg)",
          borderTopLeftRadius: "var(--r-hero)",
          borderTopRightRadius: "var(--r-hero)",
          paddingBottom: "env(safe-area-inset-bottom)",
          animation: "lifey-sheet-enter var(--dur-sheet) var(--ease-enter)",
        }}
      >
        <div className="flex justify-center pt-2 pb-1">
          <div style={{ width: 36, height: 4, borderRadius: "var(--r-pill)", background: "var(--outline)" }} />
        </div>
        {children}
      </div>
    </div>
  );
});
