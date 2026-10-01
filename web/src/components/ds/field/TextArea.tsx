"use client";

import { forwardRef, useId, type TextareaHTMLAttributes } from "react";
import { Field, fieldDescribedBy } from "./Field";

export interface TextAreaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  hint?: string;
  error?: string;
}

export const TextArea = forwardRef<HTMLTextAreaElement, TextAreaProps>(function TextArea(
  { label, hint, error, id, required, disabled, className, rows = 4, ...rest },
  ref,
) {
  const autoId = useId();
  const inputId = id ?? autoId;

  return (
    <Field label={label} hint={hint} error={error} required={required} disabled={disabled} htmlFor={inputId} autoHeight className={className}>
      <textarea
        ref={ref}
        id={inputId}
        rows={rows}
        disabled={disabled}
        required={required}
        aria-invalid={!!error}
        aria-describedby={fieldDescribedBy(inputId, error, hint)}
        className="py-2.5 resize-y"
        {...rest}
      />
    </Field>
  );
});
