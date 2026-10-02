import { useId, type ReactNode } from "react";
import { Field } from "./Field";

export interface ReadOnlyFieldProps {
  label?: string;
  value: ReactNode;
  className?: string;
}

/** Plain text, no field shape (DS-03, `client-032`: "Kliens · csak
 *  olvasható") — a convenience over `<Field readOnly>` for the common case
 *  of showing one value with no editable control underneath it at all. */
export function ReadOnlyField({ label, value, className }: ReadOnlyFieldProps) {
  const id = useId();
  return (
    <Field readOnly htmlFor={id} label={label} readOnlyValue={value} className={className}>
      {value}
    </Field>
  );
}
