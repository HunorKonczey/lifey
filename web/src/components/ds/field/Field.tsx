import type { ReactNode } from "react";

/** The id `Field` gives its hint/error paragraph — call sites put this on
 *  the real `<input>`'s `aria-describedby` (the wrapping div isn't the
 *  form control, so putting it there would be inert). */
export function fieldDescribedBy(htmlFor: string, error?: string, hint?: string): string | undefined {
  if (error) return `${htmlFor}-error`;
  if (hint) return `${htmlFor}-hint`;
  return undefined;
}

export interface FieldProps {
  label?: string;
  hint?: string;
  error?: string;
  required?: boolean;
  disabled?: boolean;
  /** Plain text, no field shape (DS-03) — for a value the viewer can't edit
   *  here (a trainer viewing a client's field, `client-032`). */
  readOnly?: boolean;
  readOnlyValue?: ReactNode;
  htmlFor: string;
  /** 52px on auth pages, 44px in dense panels (D-W0.9). */
  size?: "auth" | "dense";
  /** A `<textarea>` grows past the fixed input height — top-aligned content
   *  with a `min-height` instead of a fixed one. */
  autoHeight?: boolean;
  /** The actual `<input>`/`<textarea>`, rendered inside the field shape. */
  children: ReactNode;
  className?: string;
}

/**
 * The chrome every form field shares (D-W0.9/DS-03): label above, hint or
 * error below, default/hover/focus/error/disabled/read-only states. The
 * actual input lives inside `[data-ring-frame]` so it gets the field's own
 * 2px-primary-border + 4px-halo focus style (globals.css), not the general
 * `:focus-visible` ring.
 */
export function Field({
  label,
  hint,
  error,
  required,
  disabled,
  readOnly,
  readOnlyValue,
  htmlFor,
  size = "dense",
  autoHeight = false,
  children,
  className,
}: FieldProps) {
  if (readOnly) {
    return (
      <div className={className}>
        {label && (
          <span className="type-label block mb-1" style={{ color: "var(--text-3)" }}>
            {label}
          </span>
        )}
        <div className="type-body" style={{ color: "var(--text)" }}>
          {readOnlyValue ?? children}
        </div>
      </div>
    );
  }

  const height = size === "auth" ? 52 : 44;

  return (
    <div className={className}>
      {label && (
        <label htmlFor={htmlFor} className="type-label block mb-1.5" style={{ color: "var(--text-3)" }}>
          {label}
          {required && <span style={{ color: "var(--heart)" }}> *</span>}
        </label>
      )}
      <div
        data-ring-frame
        className={[
          "lifey-field",
          error ? "lifey-field-error" : "",
          disabled ? "opacity-45 pointer-events-none" : "",
          autoHeight ? "lifey-field-autoheight" : "",
        ]
          .filter(Boolean)
          .join(" ")}
        style={autoHeight ? { minHeight: height, borderRadius: "var(--r-control)" } : { height, borderRadius: "var(--r-control)" }}
      >
        {children}
      </div>
      {error ? (
        <p id={`${htmlFor}-error`} role="alert" className="type-body-s mt-1" style={{ color: "var(--heart)" }}>
          {error}
        </p>
      ) : hint ? (
        <p id={`${htmlFor}-hint`} className="type-body-s mt-1" style={{ color: "var(--text-3)" }}>
          {hint}
        </p>
      ) : null}
    </div>
  );
}
