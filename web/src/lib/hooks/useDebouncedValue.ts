"use client";

import { useEffect, useState } from "react";

/** `value`, but only after it has stayed the same for `delayMs` — typing a word is one change, not one per letter. */
export function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [settled, setSettled] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setSettled(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);

  return settled;
}
