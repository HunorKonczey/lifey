"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { queryKeys } from "@/lib/api/queryKeys";
import { useLocale } from "@/lib/hooks/useLocale";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { chatApi } from "../api";
import { SEARCH_DEBOUNCE_MS, SEARCH_MIN_LENGTH, highlightSegments } from "../thread";
import type { MessageResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

interface ChatSearchProps {
  conversationId: number;
  ownUserId: number;
  peerName: string;
  /** Raw input value — debounced here, so the caller can stay a controlled input. */
  query: string;
}

/**
 * Search results inside one thread. Replaces the message stream while a search
 * is running; the thread's own cache is left completely alone (§20.4/2).
 */
export function ChatSearch({ conversationId, ownUserId, peerName, query }: ChatSearchProps) {
  const t = useTranslations("chat");
  const locale = useLocale((s) => s.locale);
  const [debounced, setDebounced] = useState(query.trim());

  // Typing a word should be one request, not one per letter.
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(query.trim()), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [query]);

  const enabled = debounced.length >= SEARCH_MIN_LENGTH;
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.chat.search(conversationId, debounced),
    queryFn: () => chatApi.searchMessages(conversationId, debounced),
    enabled,
    staleTime: 30_000,
  });

  if (!enabled) {
    return (
      <EmptyState
        icon="search"
        title={t("searchPromptTitle")}
        body={t("searchPromptBody", { min: SEARCH_MIN_LENGTH })}
      />
    );
  }
  if (isLoading) return <ResultsSkeleton />;
  if (isError) return <ErrorState onRetry={refetch} />;

  const results = data?.items ?? [];
  if (results.length === 0) {
    return <EmptyState icon="search_off" title={t("searchNoResultsTitle")} body={t("searchNoResultsBody")} />;
  }

  return (
    <div className="flex flex-col gap-1.5">
      <p className="text-[11px] font-bold px-1 pb-1" style={{ color: "var(--muted)" }}>
        {t("searchResultCount", { count: results.length })}
        {data?.hasMore ? ` · ${t("searchMoreResults")}` : ""}
      </p>
      {results.map((message) => (
        <ResultRow
          key={message.id}
          message={message}
          own={message.senderId === ownUserId}
          peerName={peerName}
          term={debounced}
          locale={locale}
        />
      ))}
    </div>
  );
}

function ResultRow({
  message,
  own,
  peerName,
  term,
  locale,
}: {
  message: MessageResponse;
  own: boolean;
  peerName: string;
  term: string;
  locale: keyof typeof DATE_LOCALES;
}) {
  const t = useTranslations("chat");
  const when = format(new Date(message.createdAt), "yyyy. MMM d. H:mm", {
    locale: DATE_LOCALES[locale],
  });

  return (
    <div
      className="rounded-[var(--r-md)] px-4 py-3"
      style={{ background: "var(--surface-container)" }}
    >
      <div className="flex items-baseline gap-2 mb-1">
        <span className="text-[12px] font-extrabold" style={{ color: "var(--on-surface)" }}>
          {own ? t("you") : peerName}
        </span>
        <span className="text-[10.5px] font-semibold" style={{ color: "var(--muted)" }}>
          {when}
        </span>
        {message.attachment && (
          <span className="text-[10.5px] font-semibold" style={{ color: "var(--muted)" }}>
            {t("imagePreview")}
          </span>
        )}
      </div>
      <p
        className="text-[13.5px] leading-relaxed whitespace-pre-wrap break-words"
        style={{ color: "var(--on-surface-variant)", fontWeight: 500 }}
      >
        {highlightSegments(message.body ?? "", term).map((segment, index) =>
          segment.match ? (
            <mark
              key={index}
              style={{
                background: "color-mix(in srgb, var(--primary) 30%, transparent)",
                color: "var(--on-surface)",
                borderRadius: 3,
              }}
            >
              {segment.text}
            </mark>
          ) : (
            <span key={index}>{segment.text}</span>
          ),
        )}
      </p>
    </div>
  );
}

function ResultsSkeleton() {
  return (
    <div className="flex flex-col gap-2">
      {[0, 1, 2].map((i) => (
        <div key={i} className="skeleton-pulse h-[62px] rounded-[var(--r-md)]" />
      ))}
    </div>
  );
}
