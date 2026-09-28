"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Sidebar } from "@/components/shell/Sidebar";
import { useSidebarState } from "@/lib/hooks/useSidebarState";
import { clientGroupsFor, TRAINER_NAV_GROUPS, SUPERADMIN_NAV_GROUPS } from "@/components/shell/navConfig";
import type { SessionUser } from "@/features/auth/types";

const FIXTURE_USER: SessionUser = {
  id: 1,
  email: "nagy.kata@example.com",
  firstName: "Nagy",
  lastName: "Kata",
  roles: ["ROLE_USER", "ROLE_TRAINER"],
};

type Role = "client" | "trainer" | "superadmin";

const ROLE_LABELS: Record<Role, string> = { client: "Client", trainer: "Trainer", superadmin: "Superadmin" };
const ROLES: Role[] = ["client", "trainer", "superadmin"];

/**
 * DS-02's sidebar + account menu (D-W0.20/23/24), standalone with fixture
 * data — `e2e/ds/shell.spec.ts`'s target. Defaults to the client config (the
 * spec's assumptions — one "Dashboard" link, no group headers — depend on
 * this being the initial state); `AppShell` itself isn't demoed here since
 * it needs a real session, but `Sidebar` takes everything it shows as props,
 * so it renders identically outside the authenticated app either way.
 */
export function ShellSection() {
  const { collapsed, toggle } = useSidebarState();
  const admin = useTranslations("admin");
  const superadmin = useTranslations("superadmin");
  const [role, setRole] = useState<Role>("client");

  const groups =
    role === "client" ? clientGroupsFor(FIXTURE_USER) : role === "trainer" ? TRAINER_NAV_GROUPS : SUPERADMIN_NAV_GROUPS;
  const roleBadge =
    role === "trainer"
      ? { icon: "fitness_center", label: admin("chip") }
      : role === "superadmin"
        ? { icon: "shield_person", label: superadmin("chip") }
        : undefined;

  return (
    <div className="flex flex-col gap-3">
      <div className="flex gap-2">
        {ROLES.map((r) => (
          <button
            key={r}
            type="button"
            onClick={() => setRole(r)}
            className="lifey-button px-3 h-8 rounded-[var(--r-pill)] type-body-s"
            style={{ background: role === r ? "var(--primary)" : "var(--nested)", color: role === r ? "var(--on-primary)" : "var(--text)" }}
          >
            {ROLE_LABELS[r]}
          </button>
        ))}
      </div>
      <div style={{ height: 560, display: "flex", background: "var(--bg)", borderRadius: "var(--r-card)", overflow: "hidden" }}>
        <Sidebar
          user={FIXTURE_USER}
          avatarUrl={null}
          collapsed={collapsed}
          onToggleCollapsed={toggle}
          onLogout={() => {}}
          groups={groups}
          roleBadge={roleBadge}
          roleRing={role === "trainer" ? "trainer" : role === "superadmin" ? "superadmin" : undefined}
          chipSubtitle={roleBadge?.label}
          showSettingsRow={role === "client"}
        />
      </div>
    </div>
  );
}
