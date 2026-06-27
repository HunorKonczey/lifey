interface SkeletonProps {
  variant?: "card" | "table" | "chart" | "text";
  className?: string;
}

export function Skeleton({ variant = "card", className = "" }: SkeletonProps) {
  if (variant === "table") {
    return (
      <div className={`flex flex-col gap-2 ${className}`}>
        {/* header */}
        <div className="skeleton-pulse h-10 rounded-[var(--r-sm)] opacity-70" />
        {/* rows */}
        {Array.from({ length: 5 }).map((_, i) => (
          <div
            key={i}
            className="skeleton-pulse h-12 rounded-[var(--r-sm)]"
            style={{ opacity: 1 - i * 0.1 }}
          />
        ))}
      </div>
    );
  }

  if (variant === "chart") {
    return (
      <div className={`skeleton-pulse rounded-[var(--r-lg)] ${className}`} style={{ height: 200 }} />
    );
  }

  if (variant === "text") {
    return (
      <div className={`flex flex-col gap-2 ${className}`}>
        <div className="skeleton-pulse h-4 rounded-[var(--r-sm)] w-3/4" />
        <div className="skeleton-pulse h-4 rounded-[var(--r-sm)] w-1/2" />
      </div>
    );
  }

  // card (default)
  return (
    <div
      className={`skeleton-pulse rounded-[var(--r-card)] ${className}`}
      style={{ minHeight: 120 }}
    />
  );
}
