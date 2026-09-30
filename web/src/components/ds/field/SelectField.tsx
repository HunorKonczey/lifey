"use client";

import { forwardRef, useId, type SelectHTMLAttributes } from "react";
import { Icon } from "../Icon";
import { Field, fieldDescribedBy } from "./Field";

export interface SelectFieldProps extends Omit<SelectHTMLAttributes<HTMLSelectElement>, "size"> {
  label?: string;
  hint?: string;
  error?: string;
  size?: "auth" | "dense";
}

/**
 * A native `<select>` in the DS field shape (W3.12) — label above, the field's own hover / focus ring, a chevron.
 * Native on purpose: the lists here (muscle groups, equipment) are short and the platform picker is the best
 * one on a phone.
 */
export const SelectField = forwardRef<HTMLSelectElement, SelectFieldProps>(function SelectField(
  { label, hint, error, size, id, required, disabled, className, children, ...rest },
  ref,
) {
  const autoId = useId();
  const selectId = id ?? autoId;

  return (
    <Field label={label} hint={hint} error={error} required={required} disabled={disabled} htmlFor={selectId} size={size} className={className}>
      <select
        ref={ref}
        id={selectId}
        disabled={disabled}
        required={required}
        aria-invalid={!!error}
        aria-describedby={fieldDescribedBy(selectId, error, hint)}
        className="cursor-pointer appearance-none"
        {...rest}
      >
        {children}
      </select>
      <Icon name="expand_more" size={20} color="var(--text-3)" />
    </Field>
  );
});
