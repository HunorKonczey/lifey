"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Sidebar } from "@/components/shell/Sidebar";
import { useSidebarState } from "@/lib/hooks/useSidebarState";
import { clientGroupsFor, TRAINER_NAV_GROUPS } from "@/components/shell/navConfig";
import type { SessionUser } from "@/features/auth/types";

const FIXTURE_USER: SessionUser = {
  id: 1,
  email: "nagy.kata@example.com",
  firstName: "Nagy",
  lastName: "Kata",
  roles: ["ROLE_USER", "ROLE_TRAINER"],
};

type Role = "client" | "trainer";

/**
 * DS-02's sidebar + account menu (D-W0.20/23), standalone with fixture
 * data — `e2e/ds/shell.spec.ts`'s target. Defaults to the client config (the
 * spec's assumptions — one "Dashboard" link, no group headers — depend on
 * this being the initial state); `AppShell` itself isn't demoed here since
 * it needs a real session, but `Sidebar` takes everything it shows as props,
 * so it renders identically outside the authenticated app either way.
 */
export function ShellSection() {
  const { collapsed, toggle } = useSidebarState();
  const admin = useTranslations("admin");
  const [role, setRole] = useState<Role>("client");

  return (
    <div className="flex flex-col gap-3">
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => setRole("client")}
          className="lifey-button px-3 h-8 rounded-[var(--r-pill)] type-body-s"
          style={{ background: role === "client" ? "var(--primary)" : "var(--nested)", color: role === "client" ? "var(--on-primary)" : "var(--text)" }}
        >
          Client
        </button>
        <button
          type="button"
          onClick={() => setRole("trainer")}
          className="lifey-button px-3 h-8 rounded-[var(--r-pill)] type-body-s"
          style={{ background: role === "trainer" ? "var(--primary)" : "var(--nested)", color: role === "trainer" ? "var(--on-primary)" : "var(--text)" }}
        >
          Trainer
        </button>
      </div>
      <div style={{ height: 560, display: "flex", background: "var(--bg)", borderRadius: "var(--r-card)", overflow: "hidden" }}>
        <Sidebar
          user={FIXTURE_USER}
          avatarUrl={null}
          collapsed={collapsed}
          onToggleCollapsed={toggle}
          onLogout={() => {}}
          groups={role === "client" ? clientGroupsFor(FIXTURE_USER) : TRAINER_NAV_GROUPS}
          roleBadge={role === "trainer" ? { icon: "fitness_center", label: admin("chip") } : undefined}
          roleRing={role === "trainer" ? "trainer" : undefined}
          chipSubtitle={role === "trainer" ? admin("chip") : undefined}
          showSettingsRow={role === "client"}
        />
      </div>
    </div>
  );
}
