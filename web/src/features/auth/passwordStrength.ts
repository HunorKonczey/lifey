/**
 * The register form's strength meter (W6.3): four segments, never a rule the backend does not have — the only hard
 * requirement is 8 characters (`registerSchema`); this just tells the person how far past it they are.
 *
 * Points: 8+ characters, 12+ characters, upper and lower case, a digit, a symbol. Under 8 characters the password
 * is "weak" whatever else it has; from 8 up, segments = the points earned (capped at 4).
 */
export type StrengthLevel = 0 | 1 | 2 | 3 | 4;

export function passwordStrength(password: string): StrengthLevel {
  if (password.length === 0) return 0;
  if (password.length < 8) return 1;
  const points = [
    true,
    password.length >= 12,
    /[a-z]/.test(password) && /[A-Z]/.test(password),
    /\d/.test(password),
    /[^A-Za-z0-9]/.test(password),
  ].filter(Boolean).length;
  return Math.min(4, Math.max(2, points)) as StrengthLevel;
}
