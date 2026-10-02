"use client";

import { useTranslations } from "next-intl";
import { TintedChip } from "@/components/ds";
import { primaryRole } from "../userRoles";

const COLOR = { USER: "var(--text-2)", TRAINER: "var(--role)", ADMIN: "var(--text)" } as const;

/** The user's role in words (never `ROLE_…`): Kliens neutral, Edző clay (the trainer's colour everywhere), Superadmin neutral light. */
export function RoleChip({ roles }: { roles: readonly string[] }) {
  const t = useTranslations("superadmin");
  const kind = primaryRole(roles);
  return <TintedChip label={t(`role.${kind}`)} color={COLOR[kind]} />;
}
