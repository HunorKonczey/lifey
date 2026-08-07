"use client";

import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { useLocale } from "@/lib/hooks/useLocale";
import { ChatAvatar } from "./ChatAvatar";
import { ChatAttachment } from "./ChatAttachment";
import { hasImage } from "../thread";
import type { ChatReceiptState, ThreadMessage } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

/**
 * The four-state ladder from the design: waiting → left this device → reached
 * theirs → they opened it. Only the last one is filled and accented, so the
 * difference between delivered and read is carried by weight and colour on top
 * of the shape, not by colour alone.
 */
const STATE_ICON = {
  pending: "schedule",
  sent: "check",
  delivered: "done_all",
  read: "done_all",
  failed: "error",
} as const;

const RECEIPT_COLOR: Record<ChatReceiptState, string> = {
  pending: "var(--on-surface-variant)",
  sent: "var(--on-surface-variant)",
  delivered: "var(--on-surface-variant)",
  read: "var(--primary)",
  failed: "var(--error)",
};

interface MessageBubbleProps {
  message: ThreadMessage;
  own: boolean;
  /** Last of a same-sender run — the only bubble that shows avatar, time and state. */
  groupEnd: boolean;
  groupStart: boolean;
  peerName: string;
  peerUserId: number;
  /** Tick state for your own message, derived from the peer's cursors. */
  receiptState: ChatReceiptState;
  onRetry: (clientMessageId: string) => void;
  onDiscard: (clientMessageId: string) => void;
  onDelete: (messageId: number) => void;
}

export function MessageBubble({
  message,
  own,
  groupEnd,
  groupStart,
  peerName,
  peerUserId,
  receiptState,
  onRetry,
  onDiscard,
  onDelete,
}: MessageBubbleProps) {
  const t = useTranslations("chat");
  const common = useTranslations("common");
  const locale = useLocale((s) => s.locale);

  const deleted = message.deletedAt !== null;
  const time = format(new Date(message.createdAt), "H:mm", { locale: DATE_LOCALES[locale] });
  const stateLabel = own ? t(`state.${receiptState}`) : "";
  const image = !deleted && hasImage(message);
  const text = deleted ? t("deletedMessage") : message.body ?? "";
  // A picture with no caption gets no empty text bubble under it, but the
  // screen reader still needs to hear that a picture is what arrived.
  const spokenText = text || (image ? t("imageAlt") : "");

  // Only the bubble that closes a run gets the flattened corner — mid-run
  // bubbles stay fully rounded so a run reads as one block (design A3).
  const radius = own
    ? groupEnd
      ? "18px 18px 6px 18px"
      : "18px"
    : groupEnd
      ? "18px 18px 18px 6px"
      : "18px";

  return (
    <div
      className={`group flex items-end gap-2.5 ${own ? "flex-row-reverse" : ""}`}
      style={{ marginTop: groupStart ? 10 : 2 }}
    >
      {!own &&
        (groupEnd ? (
          <ChatAvatar userId={peerUserId} displayName={peerName} size={30} />
        ) : (
          <div className="w-[30px] shrink-0" aria-hidden />
        ))}

      <div className={`min-w-0 flex flex-col gap-1 ${own ? "items-end" : "items-start"}`} style={{ maxWidth: "65ch" }}>
        {image && (
          <div
            aria-label={t("bubbleA11y", {
              sender: own ? t("you") : peerName,
              time,
              text: spokenText,
              state: stateLabel,
            })}
          >
            <ChatAttachment message={message} uploading={message.state === "pending"} />
          </div>
        )}
        {/* No empty bubble under a caption-less picture — the image is the message. */}
        {(text || !image) && (
          <p
            className="px-4 py-2.5 text-[14.5px] leading-relaxed whitespace-pre-wrap break-words"
            style={{
              background: own
                ? "color-mix(in srgb, var(--primary) 20%, transparent)"
                : "var(--surface-container)",
              color: deleted ? "var(--on-surface-variant)" : "var(--on-surface)",
              fontStyle: deleted ? "italic" : undefined,
              fontWeight: 500,
              borderRadius: radius,
            }}
            aria-label={
              image
                ? undefined
                : t("bubbleA11y", {
                    sender: own ? t("you") : peerName,
                    time,
                    text: spokenText,
                    state: stateLabel,
                  })
            }
          >
            {text}
          </p>
        )}

        {groupEnd && (
          <div className={`flex items-center gap-1 mt-1 ${own ? "mr-1" : "ml-1"}`}>
            <span className="text-[10.5px] font-semibold" style={{ color: "var(--muted)" }}>
              {time}
            </span>
            {own && (
              <span
                className="material-symbols-rounded text-[14px]"
                title={stateLabel}
                aria-label={stateLabel}
                style={{
                  color: RECEIPT_COLOR[receiptState],
                  fontVariationSettings:
                    receiptState === "read" || receiptState === "failed" ? "'FILL' 1" : "'FILL' 0",
                }}
              >
                {STATE_ICON[receiptState]}
              </span>
            )}
          </div>
        )}

        {message.state === "failed" && (
          <div className="flex items-center gap-3 mt-0.5 mr-1">
            <button
              onClick={() => onRetry(message.clientMessageId)}
              className="text-[11px] font-extrabold"
              style={{ color: "var(--error)" }}
            >
              {common("retry")}
            </button>
            <button
              onClick={() => onDiscard(message.clientMessageId)}
              className="text-[11px] font-bold"
              style={{ color: "var(--on-surface-variant)" }}
            >
              {t("discard")}
            </button>
          </div>
        )}
      </div>

      {own && !deleted && message.id !== null && (
        <button
          onClick={() => onDelete(message.id as number)}
          title={t("deleteMessage")}
          aria-label={t("deleteMessage")}
          className="mb-5 w-7 h-7 rounded-[9px] flex items-center justify-center shrink-0 opacity-0 transition-opacity group-hover:opacity-100 focus:opacity-100"
          style={{ color: "var(--on-surface-variant)" }}
        >
          <span className="material-symbols-rounded text-[17px]">delete</span>
        </button>
      )}
    </div>
  );
}
