/**
 * A round avatar with the person's initials (D-W0.7) — a port of mobile's
 * `MonogramAvatar`. Initials come from the **name**, never the first letter
 * of the e-mail (the e-mail is only the fallback when there is no name).
 * The signed-in user's own avatar stays brand-tint (no `color`); everyone
 * else gets a stable metric hue from {@link colorForSeed} (their id or
 * e-mail), so a list of clients or chat threads is easy to scan by eye —
 * same seed, same colour, every time. With `image` the photo is shown and
 * the initials are the fallback if it fails to load.
 */

const METRIC_VARS = ["--m-water", "--m-steps", "--m-fat", "--m-carbs", "--m-kcal", "--m-weight"] as const;

/** "AK" from "Anna Kovács", "A" from "Anna", the e-mail's first letter with
 *  no name, "?" with neither. */
export function initialsFor(name?: string | null, email?: string | null): string {
  const words = (name ?? "").trim().split(/\s+/).filter(Boolean);
  const first = (s: string) => [...s][0]?.toUpperCase() ?? "";
  if (words.length >= 2) return first(words[0]) + first(words[words.length - 1]);
  if (words.length === 1) return first(words[0]);
  const mail = (email ?? "").trim();
  if (mail) return first(mail);
  return "?";
}

/** A stable per-person hue from the metric palette — same hashing as
 *  mobile's `MonogramAvatar.colorFor` (`codeUnits`/`charCodeAt` agree for
 *  the BMP), so the two clients pick the same colour for the same seed. */
export function colorForSeed(seed: string): string {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) & 0x7fffffff;
  }
  return `var(${METRIC_VARS[hash % METRIC_VARS.length]})`;
}

export interface AvatarProps {
  name?: string | null;
  email?: string | null;
  /** Diameter in px. The canvases use 44 (header, chat), 48 (client card), 56 (settings profile). */
  size?: number;
  /** A per-person tint from {@link colorForSeed}; omit for the signed-in user's own brand-tint avatar. */
  color?: string;
  /** Photo URL; falls back to initials on error or while it's missing. */
  src?: string;
  /** Clay for the trainer role, a neutral outline for superadmin — DS-02. */
  roleRing?: "trainer" | "superadmin";
  className?: string;
}

export function Avatar({ name, email, size = 44, color, src, roleRing, className }: AvatarProps) {
  // --chip-tint (16% dark / 12% light, D-W0.4) blended toward transparent,
  // not var(--bg) — mobile's MonogramAvatar blends toward its scaffold
  // background specifically (Color.alphaBlend(bg, p.bg)), but ported
  // literally that under-contrasts on the web: a hard-coded 16% regardless
  // of theme first (axe: 4.2:1), and even corrected to 12% in light, still
  // 4.44:1 against bare --bg (axe again) because --bg itself is a warmer,
  // darker cream than mobile's equivalent. Blending toward transparent lets
  // the avatar composite against whatever it actually sits on — every real
  // placement (row, header, card) clears AA at 12%/16% this way (verified
  // for all eight metrics), where a fixed target color can't account for
  // where the avatar ends up in a wider page.
  const bg = color ? `color-mix(in srgb, ${color} var(--chip-tint), transparent)` : "var(--primary-tint)";
  const fg = color ?? "var(--on-primary-tint)";
  const initials = initialsFor(name, email);
  const label = name ?? email ?? undefined;

  return (
    <span
      role="img"
      aria-label={label}
      className={["relative inline-flex items-center justify-center rounded-full shrink-0 overflow-hidden", className]
        .filter(Boolean)
        .join(" ")}
      style={{
        width: size,
        height: size,
        background: bg,
        boxShadow: roleRing ? `0 0 0 2px ${roleRing === "trainer" ? "var(--role)" : "var(--outline)"}` : undefined,
      }}
    >
      <span className="num" style={{ fontSize: size * 0.34, color: fg, letterSpacing: 0 }} aria-hidden="true">
        {initials}
      </span>
      {src && (
        // A decorative avatar thumbnail, not an optimizable content image;
        // the initials span underneath stays as the fallback if this errors.
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={src}
          alt=""
          width={size}
          height={size}
          className="absolute inset-0 w-full h-full object-cover"
          onError={(e) => {
            e.currentTarget.style.display = "none";
          }}
        />
      )}
    </span>
  );
}
