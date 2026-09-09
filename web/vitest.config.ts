import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    tsconfigPaths: true,
  },
  // next-intl's compiled ESM imports the bare specifier "next/server", which
  // `next` (no "exports" entry for that subpath) only resolves under Next's
  // own bundler. Vitest's node environment externalizes node_modules by
  // default (loads them via Node's stricter native resolver, bypassing Vite's
  // `resolve`), so next-intl has to be forced through Vite's own resolution
  // instead — only surfaced once src/proxy.ts (next-intl/middleware) existed.
  ssr: {
    noExternal: ["next-intl"],
  },
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
});
