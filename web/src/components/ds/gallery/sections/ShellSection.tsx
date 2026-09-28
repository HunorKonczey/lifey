"use client";

import { Sidebar } from "@/components/shell/Sidebar";
import { useSidebarState } from "@/lib/hooks/useSidebarState";
import type { SessionUser } from "@/features/auth/types";

const FIXTURE_USER: SessionUser = {
  id: 1,
  email: "nagy.kata@example.com",
  firstName: "Nagy",
  lastName: "Kata",
  roles: ["ROLE_USER", "ROLE_TRAINER"],
};

/**
 * DS-02's client sidebar + account menu (D-W0.20), standalone with fixture
 * data — the target of `e2e/ds/shell.spec.ts`. `AppShell` itself isn't
 * demoed here since it needs a real session; `Sidebar` takes everything it
 * shows as props, so it works identically outside the authenticated app.
 */
export function ShellSection() {
  const { collapsed, toggle } = useSidebarState();

  return (
    <div style={{ height: 560, display: "flex", background: "var(--bg)", borderRadius: "var(--r-card)", overflow: "hidden" }}>
      <Sidebar
        user={FIXTURE_USER}
        avatarUrl={null}
        collapsed={collapsed}
        onToggleCollapsed={toggle}
        onLogout={() => {}}
      />
    </div>
  );
}
