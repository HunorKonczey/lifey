/**
 * How code outside the React tree empties the TanStack Query cache — the auth store does on logout and when a different
 * account signs in. It goes through this hook instead of importing `queryClient` because the marketing header reads
 * the session store too, and that import dragged the whole of query-core (~10 KB gzipped) into the first load of every
 * marketing page (LIF-117). Marketing pages have no query cache; the app's `queryClient` registers itself on load.
 */
let clearer: (() => void) | null = null;

export function registerQueryCacheClearer(clear: () => void) {
  clearer = clear;
}

export function clearQueryCache() {
  clearer?.();
}
