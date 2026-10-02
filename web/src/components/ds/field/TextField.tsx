"use client";

import { forwardRef, useId, type InputHTMLAttributes } from "react";
import { Icon } from "../Icon";
import { Field, fieldDescribedBy } from "./Field";

export interface TextFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "size"> {
  label?: string;
  hint?: string;
  error?: string;
  invalid?: boolean;
  size?: "auth" | "dense";
  leadingIcon?: string;
}

export const TextField = forwardRef<HTMLInputElement, TextFieldProps>(function TextField(
  { label, hint, error, invalid, size, leadingIcon, id, required, disabled, className, ...rest },
  ref,
) {
  const autoId = useId();
  const inputId = id ?? autoId;

  return (
    <Field label={label} hint={hint} error={error} invalid={invalid} required={required} disabled={disabled} htmlFor={inputId} size={size} className={className}>
      {leadingIcon && <Icon name={leadingIcon} size={18} color="var(--text-3)" />}
      <input
        ref={ref}
        id={inputId}
        disabled={disabled}
        required={required}
        aria-invalid={!!error || invalid}
        aria-describedby={fieldDescribedBy(inputId, error, hint)}
        {...rest}
      />
    </Field>
  );
});
