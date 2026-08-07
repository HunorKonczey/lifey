"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { queryKeys } from "@/lib/api/queryKeys";
import { chatApi } from "../api";
import type { ThreadMessage } from "../types";

/**
 * Object URLs cached by message id for the life of the tab, the same way
 * RecipeThumbnail and the avatars do it: revoking on unmount would break the
 * back/forward cache, and a thread is scrolled past far more often than it is
 * closed.
 */
const urlCache = new Map<number, { blob: Blob; url: string }>();

function objectUrlFor(messageId: number, blob: Blob | null | undefined): string | null {
  if (!blob) return null;
  const cached = urlCache.get(messageId);
  if (cached && cached.blob === blob) return cached.url;
  if (cached) URL.revokeObjectURL(cached.url);
  const url = URL.createObjectURL(blob);
  urlCache.set(messageId, { blob, url });
  return url;
}

/** Bubble-sized box, capped so a portrait photo can't take over the thread. */
const MAX_WIDTH = 320;
const MAX_HEIGHT = 380;

function displaySize(width: number, height: number): { width: number; height: number } {
  const scale = Math.min(MAX_WIDTH / width, MAX_HEIGHT / height, 1);
  return { width: Math.round(width * scale), height: Math.round(height * scale) };
}

interface ChatAttachmentProps {
  message: ThreadMessage;
  /** Upload still in flight — the local preview shows, dimmed, under a spinner. */
  uploading: boolean;
}

/**
 * One message's picture. The box is sized from the metadata the message
 * already carries, so it is reserved before any bytes arrive and the thread
 * never reflows as images load.
 */
export function ChatAttachment({ message, uploading }: ChatAttachmentProps) {
  const t = useTranslations("chat");
  const [open, setOpen] = useState(false);
  const messageId = message.id;

  // The local preview wins while it exists: it is already decoded, and it is
  // the only thing there is before the upload has an id to fetch with.
  const { data: blob } = useQuery({
    queryKey: queryKeys.chat.attachmentThumbnail(messageId ?? 0),
    queryFn: () => chatApi.attachmentThumbnail(messageId as number),
    enabled: messageId != null && message.attachment != null && !message.localImageUrl,
    staleTime: Infinity,
  });

  const thumbnailUrl = message.localImageUrl ?? objectUrlFor(messageId ?? 0, blob);
  const box = message.attachment
    ? displaySize(message.attachment.width, message.attachment.height)
    : { width: 240, height: 240 };

  return (
    <>
      <button
        onClick={() => messageId != null && !uploading && setOpen(true)}
        aria-label={t("openImage")}
        className="relative block overflow-hidden"
        style={{
          width: box.width,
          height: box.height,
          maxWidth: "100%",
          borderRadius: 14,
          background: "var(--surface-container)",
          cursor: messageId != null && !uploading ? "zoom-in" : "default",
        }}
      >
        {thumbnailUrl && (
          // Blob and object URLs aren't compatible with next/image's optimizer.
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={thumbnailUrl}
            alt={t("imageAlt")}
            className="w-full h-full object-cover"
            style={{ opacity: uploading ? 0.55 : 1 }}
          />
        )}
        {uploading && (
          <span
            className="absolute inset-0 flex items-center justify-center"
            style={{ color: "var(--on-surface)" }}
          >
            <span className="material-symbols-rounded text-[26px] animate-spin">progress_activity</span>
          </span>
        )}
      </button>

      {open && messageId != null && (
        <ImageLightbox messageId={messageId} onClose={() => setOpen(false)} />
      )}
    </>
  );
}

/**
 * Full-size view. Deliberately a separate request from the thumbnail: a thread
 * of pictures should cost thumbnails, and the full image only when someone
 * actually wants to look at one.
 */
function ImageLightbox({ messageId, onClose }: { messageId: number; onClose: () => void }) {
  const t = useTranslations("chat");
  const { data: blob, isLoading } = useQuery({
    queryKey: queryKeys.chat.attachment(messageId),
    queryFn: () => chatApi.attachment(messageId),
    staleTime: Infinity,
  });

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);

  const url = blob ? URL.createObjectURL(blob) : null;
  useEffect(() => () => {
    if (url) URL.revokeObjectURL(url);
  }, [url]);

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={t("imageAlt")}
      onClick={onClose}
      className="fixed inset-0 z-50 flex items-center justify-center p-8"
      style={{ background: "rgba(0,0,0,.82)" }}
    >
      <button
        onClick={onClose}
        aria-label={t("closeImage")}
        className="absolute top-5 right-6 w-10 h-10 rounded-full flex items-center justify-center"
        style={{ background: "rgba(255,255,255,.12)", color: "#fff" }}
      >
        <span className="material-symbols-rounded text-[22px]">close</span>
      </button>
      {isLoading || !url ? (
        <span className="material-symbols-rounded text-[32px] animate-spin" style={{ color: "#fff" }}>
          progress_activity
        </span>
      ) : (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={url}
          alt={t("imageAlt")}
          onClick={(e) => e.stopPropagation()}
          className="max-w-full max-h-full object-contain rounded-[var(--r-md)]"
        />
      )}
    </div>
  );
}
