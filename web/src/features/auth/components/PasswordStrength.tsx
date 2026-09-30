"use client";

import { useTranslations } from "next-intl";
import { passwordStrength, type StrengthLevel } from "../passwordStrength";

const COLOR: Record<StrengthLevel, string> = {
  0: "var(--control)",
  1: "var(--heart)",
  2: "var(--m-kcal)",
  3: "var(--improvement)",
  4: "var(--improvement)",
};

/** Four segments and a word under the password field (W6-B): "Erős jelszó". Announced politely as it changes. */
export function PasswordStrength({ password }: { password: string }) {
  const t = useTranslations("auth");
  const level = passwordStrength(password);
  if (level === 0) return null;
  return (
    <div className="pt-2" data-testid="password-strength">
      <div className="grid grid-cols-4 gap-1" aria-hidden>
        {[1, 2, 3, 4].map((i) => (
          <span key={i} style={{ height: 4, borderRadius: 2, background: i <= level ? COLOR[level] : "var(--control)" }} />
        ))}
      </div>
      <p className="type-body-s mt-1.5" style={{ color: COLOR[level], fontWeight: 600 }} role="status">
        {t(`strength_${level}`)}
      </p>
    </div>
  );
}
