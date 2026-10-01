"use client";

import Link from "next/link";
import { useFormat } from "@/lib/format/useFormat";
import { Icon } from "@/components/ds";
import type { WeekSummary } from "../clientSignals";
import { ClientAvatar, clientDisplayName } from "./ClientAvatar";
import { useLastActivityLabel } from "./ClientCard";
import type { TrainerClientResponse } from "../types";

/**
 * The clients on a phone (W7-E): one row each instead of a card — avatar, name, the last-activity line (heart when the
 * client has gone quiet), and on the right the week's workouts "2 / 4" or the 7-day calorie average, whichever the client
 * has. A row opens the client.
 */
export function ClientRows({ clients, weeks }: { clients: TrainerClientResponse[]; weeks: Map<number, WeekSummary> }) {
  const fmt = useFormat();
  const label = useLastActivityLabel();
  return (
    <ul className="flex flex-col overflow-hidden" style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }}>
      {clients.map((c, i) => {
        const a = label(c);
        const w = weeks.get(c.clientId);
        return (
          <li key={c.clientId} style={{ borderTop: i ? "1px solid var(--hairline)" : undefined }}>
            <Link
              href={`/admin/clients/${c.clientId}`}
              data-testid="client-card"
              data-client-email={c.clientEmail}
              className="lifey-button flex items-center gap-3.5 px-4 min-h-[68px]"
            >
              <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={44} />
              <span className="flex flex-col flex-1 min-w-0">
                <span className="truncate" style={{ fontSize: 16, fontWeight: 800 }}>{clientDisplayName(c)}</span>
                <span className="truncate type-body-s" style={{ color: a.alert ? "var(--heart)" : "var(--text-2)", fontWeight: a.alert ? 700 : 400 }}>{a.text}</span>
              </span>
              <span className="num shrink-0 text-right" style={{ fontWeight: 800 }}>
                {w && w.scheduled > 0 ? `${w.done} / ${w.scheduled}` : c.avgCalories7d != null ? `${fmt.number(c.avgCalories7d, 0)}` : "—"}
              </span>
              <Icon name="chevron_right" size={20} color="var(--text-3)" />
            </Link>
          </li>
        );
      })}
    </ul>
  );
}
