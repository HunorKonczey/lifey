"use client";

import { useTranslations } from "next-intl";
import { IconButton } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { ChatAvatar } from "./ChatAvatar";
import { ChatAttachment } from "./ChatAttachment";
import { ChatCardTile } from "./ChatCardTile";
import { hasCard, hasImage } from "../thread";
import type { ChatReceiptState, ThreadMessage } from "../types";

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
  pending: "var(--text-3)",
  sent: "var(--text-3)",
  delivered: "var(--text-3)",
  read: "var(--primary)",
  failed: "var(--heart)",
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
  const fmt = useFormat();

  const deleted = message.deletedAt !== null;
  const time = fmt.time(new Date(message.createdAt));
  const stateLabel = own ? t(`state.${receiptState}`) : "";
  const image = !deleted && hasImage(message);
  const card = hasCard(message) ? message.card : null;
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

      <div className={`min-w-0 flex flex-col gap-1 ${own ? "items-end" : "items-start"}`} style={{ maxWidth: 720 }}>
        {/* The delete button belongs to the message, so it is centred on the
            bubble rather than on the row: the row also holds the time/state
            line, and aligning to that pushes the icon visibly low. */}
        <div className={`flex items-center gap-2 max-w-full ${own ? "flex-row-reverse" : ""}`}>
          <div className={`min-w-0 flex flex-col gap-1 ${own ? "items-end" : "items-start"}`}>
            {/* A result card is a surface of its own; its caption is drawn inside it. */}
            {card && (
              <ChatCardTile
                card={card}
                own={own}
                caption={text || null}
                ariaLabel={(spoken) =>
                  t("bubbleA11y", { sender: own ? t("you") : peerName, time, text: spoken, state: stateLabel })
                }
              />
            )}
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
            {!card && (text || !image) && (
              <p
                className="px-4 py-2.5 text-[14.5px] leading-relaxed whitespace-pre-wrap break-words"
                style={{
                  // Own = primary fill with its own on-colour; theirs = the nested surface (W8-D).
                  background: own ? "var(--primary)" : "var(--nested)",
                  color: deleted ? (own ? "var(--on-primary)" : "var(--text-2)") : own ? "var(--on-primary)" : "var(--text)",
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
          </div>

          {own && !deleted && message.id !== null && (
            <span className="opacity-0 transition-opacity group-hover:opacity-100 focus-within:opacity-100">
              <IconButton icon="delete" label={t("deleteMessage")} size={32} onClick={() => onDelete(message.id as number)} />
            </span>
          )}
        </div>

        {groupEnd && (
          <div className={`flex items-center gap-1 mt-1 ${own ? "mr-1" : "ml-1"}`}>
            <span className="type-body-s tabular" style={{ color: "var(--text-3)", fontWeight: 500 }}>
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
              className="text-[12px] font-extrabold"
              style={{ color: "var(--heart)" }}
            >
              {common("retry")}
            </button>
            <button
              onClick={() => onDiscard(message.clientMessageId)}
              className="text-[12px] font-bold"
              style={{ color: "var(--text-2)" }}
            >
              {t("discard")}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
