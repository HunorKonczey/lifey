const PALETTE = ["#C49A6C", "#8AA0B4", "#B08AC8", "#D8B35A", "#6FA8C4", "#9DAE6B", "#E0915A"];

function colorFor(seed: number) {
  return PALETTE[seed % PALETTE.length];
}

export function initialsFor(email: string) {
  const local = email.split("@")[0] ?? email;
  const parts = local.split(/[._-]/).filter(Boolean);
  const chars = parts.length >= 2 ? [parts[0][0], parts[1][0]] : [local.slice(0, 2)];
  return chars.join("").toUpperCase().slice(0, 2);
}

export function nameFor(email: string) {
  const local = email.split("@")[0] ?? email;
  return local
    .split(/[._-]/)
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

interface ClientAvatarProps {
  clientId: number;
  email: string;
  size?: number;
}

export function ClientAvatar({ clientId, email, size = 42 }: ClientAvatarProps) {
  return (
    <div
      className="rounded-full flex items-center justify-center font-extrabold shrink-0"
      style={{
        width: size,
        height: size,
        background: colorFor(clientId),
        color: "#161611",
        fontSize: size * 0.36,
      }}
    >
      {initialsFor(email)}
    </div>
  );
}
