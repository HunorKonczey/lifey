const PALETTE = ["#C49A6C", "#8AA0B4", "#B08AC8", "#D8B35A", "#6FA8C4", "#9DAE6B", "#E0915A"];

/**
 * Monogram from the peer's display name. There is no cross-user avatar
 * endpoint — profile pictures are only reachable for your own account — so the
 * chat DTO carries no image and the design uses monograms throughout
 * (docs/chat/40-trainer-chat-plan.md §11/5).
 */
export function initialsFromName(displayName: string): string {
  const parts = displayName.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  const chars = parts.length >= 2 ? [parts[0][0], parts[1][0]] : [parts[0].slice(0, 2)];
  return chars.join("").toUpperCase().slice(0, 2);
}

interface ChatAvatarProps {
  userId: number;
  displayName: string;
  size?: number;
  /** Archived threads render the whole row muted, monogram included. */
  muted?: boolean;
}

export function ChatAvatar({ userId, displayName, size = 42, muted = false }: ChatAvatarProps) {
  return (
    <div
      aria-hidden
      className="rounded-full flex items-center justify-center font-extrabold shrink-0"
      style={{
        width: size,
        height: size,
        background: muted ? "var(--surface-high)" : PALETTE[userId % PALETTE.length],
        color: muted ? "var(--on-surface-variant)" : "#161611",
        fontSize: size * 0.33,
      }}
    >
      {initialsFromName(displayName)}
    </div>
  );
}
