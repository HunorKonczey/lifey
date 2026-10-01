import { zodResolver } from "@hookform/resolvers/zod";
import { useForm, type FieldValues, type UseFormProps } from "react-hook-form";
import type { z, ZodType } from "zod";

/**
 * `useForm` pre-wired to a Zod schema (D-W0.9) — one call instead of the
 * `resolver: zodResolver(schema)` boilerplate every form in the app already
 * repeats (see `src/features/auth/schemas.ts` + its call sites). Error
 * messages stay i18n keys (`useValidationMessage` translates them at the
 * render site), unchanged from the existing convention.
 *
 * Generic over the *schema* (`S`), not a bare `ZodType<T>` for a
 * caller-supplied `T` — zodResolver's own types don't unify against an
 * arbitrary `T`, only against the concrete shape TypeScript infers from a
 * real schema value.
 */
export function useZodForm<S extends ZodType<FieldValues>>(
  schema: S,
  options?: Omit<UseFormProps<z.infer<S>>, "resolver">,
) {
  return useForm<z.infer<S>>({
    // Zod 4's generic internals don't unify against an arbitrary `S extends
    // ZodType<FieldValues>` the way they do against a schema TypeScript sees
    // concretely — the return type above (`z.infer<S>`) is what every call
    // site actually depends on, and stays fully checked.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any -- see comment above
    resolver: zodResolver(schema as any) as never,
    mode: "onBlur",
    ...options,
  });
}
