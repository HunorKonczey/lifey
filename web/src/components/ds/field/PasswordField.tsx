"use client";

import { forwardRef, useId, useState, type InputHTMLAttributes } from "react";
import { useTranslations } from "next-intl";
import { Icon } from "../Icon";
import { Field, fieldDescribedBy } from "./Field";

export interface PasswordFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "size" | "type"> {
  label?: string;
  hint?: string;
  error?: string;
  invalid?: boolean;
  size?: "auth" | "dense";
}

/** A `TextField` with a show/hide toggle — never a separate boolean prop
 *  the consumer has to wire up (D-W0.9). */
export const PasswordField = forwardRef<HTMLInputElement, PasswordFieldProps>(function PasswordField(
  { label, hint, error, invalid, size, id, required, disabled, className, ...rest },
  ref,
) {
  const autoId = useId();
  const inputId = id ?? autoId;
  const [visible, setVisible] = useState(false);
  const t = useTranslations("common");

  return (
    <Field label={label} hint={hint} error={error} invalid={invalid} required={required} disabled={disabled} htmlFor={inputId} size={size} className={className}>
      <input
        ref={ref}
        id={inputId}
        type={visible ? "text" : "password"}
        disabled={disabled}
        required={required}
        aria-invalid={!!error || invalid}
        aria-describedby={fieldDescribedBy(inputId, error, hint)}
        {...rest}
      />
      <button
        type="button"
        onClick={() => setVisible((v) => !v)}
        aria-label={visible ? t("hidePassword") : t("showPassword")}
        aria-pressed={visible}
        className="shrink-0 -mr-1"
      >
        <Icon name={visible ? "visibility_off" : "visibility"} size={18} color="var(--text-3)" />
      </button>
    </Field>
  );
});
