import { Icon } from "@/components/ds";

/** A form-level failure in a heart-tinted box with an icon (W6 "Hiba, amit nem lehet nem észrevenni") — `role="alert"`. */
export function FormErrorBox({ message }: { message: string }) {
  return (
    <div
      role="alert"
      className="flex items-start gap-2.5 px-3.5 py-3"
      style={{ borderRadius: "var(--r-control)", background: "color-mix(in srgb, var(--heart) 10%, transparent)" }}
    >
      <Icon name="error" size={20} fill={1} color="var(--heart)" />
      <p className="type-body-s" style={{ color: "var(--text)", fontWeight: 600, fontSize: 14, lineHeight: "20px" }}>
        {message}
      </p>
    </div>
  );
}
