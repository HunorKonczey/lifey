#!/usr/bin/env node
/**
 * The first-load-JS assertion `docs/landing_page/65-web-landing-page-plan.md`
 * Prompt 11 asks for: a regression guard on the marketing tree's gzipped
 * `<script>` payload, run in CI right after `next build`.
 *
 * §8's own literal target is 100 KB for `/hu` — not met today, and not by a
 * small margin: the root layout's shared baseline (React Query, Zustand,
 * Vercel Analytics/Speed Insights) already costs ~275–283 KB before any
 * marketing content is added, a gap tracked since Prompt 3's landed notes
 * as root-layout-level work, not something to close as a side effect of a
 * CI script. Gating this check at the literal 100 KB would make it
 * permanently red from the day it's added — a check nobody can ever fix by
 * doing the right thing in a single PR trains everyone to ignore it. So
 * this asserts against BUDGET_BYTES below (a realistic ceiling with
 * headroom over the current measured baseline, not the aspirational
 * target), the same reasoning already applied to the Lighthouse thresholds
 * in `lighthouserc.cjs`. It still does real work: importing `recharts` into
 * the home page (this prompt's own verify step) added ~95 KB and tripped
 * this check immediately in manual testing before being reverted.
 *
 * Every canonical marketing route (`routing.pathnames`) is checked, HU
 * locale only — the JS payload doesn't vary by locale, only the text
 * content does, so checking both locales would double the run time for no
 * new signal.
 */
import { spawn } from "node:child_process";
import { gzipSync } from "node:zlib";
import { setTimeout as sleep } from "node:timers/promises";

const PORT = 4173;
const BASE_URL = `http://localhost:${PORT}`;
// Baseline measured on `/hu` across Prompts 3–10: ~275–283 KB gzipped.
// 320 KB leaves ~40 KB of legitimate headroom (e.g. a future page's own
// small client island, like the pricing page's ~1.4 KB) while still
// catching anything recharts-sized (~95 KB) with room to spare.
const BUDGET_BYTES = 320 * 1024;

const ROUTES = [
  "/hu",
  "/hu/edzoknek",
  "/hu/alkalmazas",
  "/hu/arak",
  "/hu/gyik",
  "/hu/letoltes",
  "/hu/kapcsolat",
  "/hu/jogi/aszf",
  "/hu/jogi/adatkezeles",
  "/hu/jogi/elallas",
  "/hu/jogi/impresszum",
];

function formatKb(bytes) {
  return (bytes / 1024).toFixed(1) + " KB";
}

async function waitForServer(url, timeoutMs = 30_000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(url);
      if (res.ok) return;
    } catch {
      // not up yet
    }
    await sleep(500);
  }
  throw new Error(`Server at ${url} did not become ready within ${timeoutMs}ms`);
}

async function measureRoute(path) {
  const html = await fetch(`${BASE_URL}${path}`).then((r) => r.text());
  const scriptSrcs = [...html.matchAll(/<script[^>]+src="(\/_next\/static\/[^"]+\.js)"/g)].map((m) => m[1]);
  const uniqueSrcs = [...new Set(scriptSrcs)];

  let totalBytes = 0;
  for (const src of uniqueSrcs) {
    const buf = await fetch(`${BASE_URL}${src}`).then((r) => r.arrayBuffer());
    totalBytes += gzipSync(Buffer.from(buf)).length;
  }
  return totalBytes;
}

async function main() {
  // `shell: true` is required on Windows for `spawn` to find `npx` at all
  // (a `.cmd` shim, not directly executable) — confirmed the hard way:
  // resolving `npx.cmd` and spawning it *without* a shell just fails with
  // `EINVAL`, Windows still needs the shell to run a batch file even when
  // named explicitly. Node's shell-mode deprecation warning is about
  // unescaped args reaching the shell, which only matters for untrusted
  // input — there is none here (the port is a local constant) — so it's
  // silenced the way Node itself suggests: one already-composed command
  // string instead of a separate args array for the shell to concatenate.
  //
  // The real cost of `shell: true`: the process tree is this script -> the
  // shell -> npx -> the actual `next-server`, and `server.kill()` only
  // reaches the immediate child (the shell) — the deeper processes are
  // left running, still holding the port, orphaned rather than killed
  // (confirmed directly: after a run, `next-server` was still listening on
  // PORT even though `.kill()` had been called and the script had exited).
  // `detached: true` + killing the whole process *group* is the fix,
  // POSIX and Windows each needing their own mechanism for it — see
  // `killServerTree` below.
  const server = spawn(`npx next start -p ${PORT}`, {
    stdio: "inherit",
    shell: true,
    detached: process.platform !== "win32",
  });

  let exitCode = 0;
  try {
    await waitForServer(`${BASE_URL}/hu`);

    console.log(`\nJS budget check — ${formatKb(BUDGET_BYTES)} per route (gzipped, unique scripts)\n`);

    for (const route of ROUTES) {
      const bytes = await measureRoute(route);
      const over = bytes > BUDGET_BYTES;
      const marker = over ? "FAIL" : "ok  ";
      console.log(`  ${marker}  ${route.padEnd(24)} ${formatKb(bytes)}`);
      if (over) {
        exitCode = 1;
        console.error(
          `\n  ${route} is ${formatKb(bytes - BUDGET_BYTES)} over the ${formatKb(BUDGET_BYTES)} budget.` +
            ` Check what changed in its client bundle before merging.\n`
        );
      }
    }
  } finally {
    await killServerTree(server);
  }

  process.exit(exitCode);
}

/**
 * Kills the whole `next start` process tree, not just the immediate shell
 * child — see the comment above `spawn()` for why that distinction matters
 * here specifically.
 */
async function killServerTree(server) {
  if (!server.pid) return;
  if (process.platform === "win32") {
    // `taskkill /t` kills the process tree rooted at this PID; plain
    // `server.kill()` only reaches the shell, leaving `next-server` running.
    await new Promise((resolve) => {
      spawn("taskkill", ["/pid", String(server.pid), "/t", "/f"], { stdio: "ignore" }).on("exit", resolve);
    });
  } else {
    // Negative PID targets the whole process group `detached: true` made
    // this the leader of.
    try {
      process.kill(-server.pid, "SIGKILL");
    } catch {
      server.kill();
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
