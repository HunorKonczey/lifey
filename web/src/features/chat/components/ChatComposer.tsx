"use client";

import { useLayoutEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Icon, IconButton } from "@/components/ds";
import {
  ACCEPTED_IMAGE_TYPES,
  MAX_ATTACHMENT_BYTES,
  MAX_MESSAGE_LENGTH,
  isMessageSendable,
  trimMessageForSend,
} from "../thread";

/** ~5 text rows before the textarea stops growing and scrolls internally. */
const MAX_ROWS_PX = 132;

interface ChatComposerProps {
  onSend: (body: string, image: File | null) => void;
  /** Set while a send is in flight; the composer stays usable, only the button waits. */
  disabled?: boolean;
  /** Surfaced when a picked file is rejected before any upload starts. */
  onError?: (message: string) => void;
  /** Called on every keystroke; the hook behind it does the throttling. */
  onTyping?: () => void;
  /** Renders the "… is typing" band. Its space is reserved either way. */
  peerTyping?: { active: boolean; name: string };
  /** Text waiting in the box when it opens (a trainer's prefilled nudge) — never sent on its own. */
  initialDraft?: string;
}

export function ChatComposer({
  onSend,
  disabled = false,
  onError,
  onTyping,
  peerTyping,
  initialDraft,
}: ChatComposerProps) {
  const t = useTranslations("chat");
  const [value, setValue] = useState(initialDraft ?? "");
  const [focused, setFocused] = useState(false);
  const [image, setImage] = useState<{ file: File; url: string } | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  // Grow with the content: reset to auto first, or the box can only ever get
  // taller (scrollHeight never shrinks below the current height).
  useLayoutEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, MAX_ROWS_PX)}px`;
  }, [value]);

  const sendable = isMessageSendable(value, image !== null) && !disabled;
  const overLimit = value.trim().length > MAX_MESSAGE_LENGTH;

  const clearImage = () => {
    if (image) URL.revokeObjectURL(image.url);
    setImage(null);
    // Reset the input, or picking the very same file again fires no change event.
    if (fileRef.current) fileRef.current.value = "";
  };

  const pick = (file: File | undefined) => {
    if (!file) return;
    // Checked here rather than left to the server: a rejected 8MB upload costs
    // the whole upload before it fails.
    if (file.size > MAX_ATTACHMENT_BYTES) {
      onError?.(t("imageTooLarge"));
      if (fileRef.current) fileRef.current.value = "";
      return;
    }
    if (image) URL.revokeObjectURL(image.url);
    setImage({ file, url: URL.createObjectURL(file) });
  };

  const submit = () => {
    if (!sendable) return;
    const body = trimMessageForSend(value);
    // A picture is a complete message; text alone still has to be non-blank.
    if (!body && !image) return;
    onSend(body ?? "", image?.file ?? null);
    setValue("");
    clearImage();
  };

  return (
    <div className="flex flex-col px-4 pb-4 shrink-0">
      <TypingBand active={peerTyping?.active ?? false} name={peerTyping?.name ?? ""} />

      {image && (
        <div className="flex items-center gap-3 mb-2.5 ml-1">
          <div
            className="relative rounded-[12px] overflow-hidden shrink-0"
            style={{ width: 64, height: 64, background: "var(--nested)" }}
          >
            {/* Object URLs aren't compatible with next/image's optimizer. */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={image.url} alt="" className="w-full h-full object-cover" />
          </div>
          <button
            onClick={clearImage}
            className="type-body-s"
            style={{ color: "var(--text-2)", fontWeight: 700 }}
          >
            {t("removeImage")}
          </button>
        </div>
      )}

      <div className="flex items-end gap-2.5">
        <input
          ref={fileRef}
          type="file"
          accept={ACCEPTED_IMAGE_TYPES}
          onChange={(e) => pick(e.target.files?.[0])}
          className="hidden"
        />
        <IconButton icon="add" label={t("attachImage")} size={46} onClick={() => fileRef.current?.click()} />
        <textarea
          ref={textareaRef}
          rows={1}
          value={value}
          onChange={(e) => {
            setValue(e.target.value);
            onTyping?.();
          }}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              submit();
            }
          }}
          placeholder={t("composerPlaceholder")}
          aria-label={t("composerPlaceholder")}
          className="flex-1 min-w-0 resize-none px-4 py-3 text-sm font-medium outline-none"
          style={{
            background: "var(--control)",
            color: "var(--text)",
            borderRadius: "var(--r-control)",
            maxHeight: MAX_ROWS_PX,
            // The composer takes the primary focus ring (W8-D), composed with the system focus shadow.
            boxShadow: focused ? "inset 0 0 0 2px var(--primary)" : undefined,
          }}
        />
        <button
          type="button"
          onClick={submit}
          disabled={!sendable}
          aria-label={t("send")}
          title={t("send")}
          className="lifey-button inline-flex h-[46px] w-[46px] shrink-0 items-center justify-center transition-opacity disabled:opacity-40"
          style={{ borderRadius: "var(--r-control)", background: "var(--primary)", color: "var(--on-primary)" }}
        >
          <Icon name="send" size={22} fill={1} />
        </button>
      </div>

      <div className="flex items-center gap-3 mt-1.5 ml-1 min-h-[15px]">
        {focused && (
          <span className="type-body-s" style={{ color: "var(--text-3)" }}>
            {t("keyboardHint")}
          </span>
        )}
        {overLimit && (
          <span className="text-[10.5px] font-extrabold ml-auto mr-1" style={{ color: "var(--heart)" }}>
            {t("tooLong", { max: MAX_MESSAGE_LENGTH })}
          </span>
        )}
      </div>
    </div>
  );
}

/**
 * "{name} is typing…", three animated dots, above the input (design D3).
 *
 * **Fixed height, always rendered.** The design's own note: appearing must
 * never shove the flow. Since the message list is anchored to the bottom, a
 * band that only exists while someone types would jolt the whole thread up on
 * every keystroke run — so the space is reserved and only the content fades.
 */
function TypingBand({ active, name }: { active: boolean; name: string }) {
  const t = useTranslations("chat");
  return (
    <div
      className="flex items-center gap-[7px] h-[18px] mb-1.5 ml-1 transition-opacity duration-150"
      style={{ opacity: active ? 1 : 0 }}
      aria-live="polite"
      aria-hidden={!active}
    >
      {[0, 0.2, 0.4].map((delay) => (
        <span
          key={delay}
          className="w-[5px] h-[5px] rounded-full"
          style={{
            background: "var(--text-2)",
            animation: active ? `chat-typing-dot 1.2s ${delay}s infinite` : undefined,
          }}
        />
      ))}
      <span className="text-[11px] font-semibold" style={{ color: "var(--text-2)" }}>
        {active ? t("isTyping", { name }) : ""}
      </span>
    </div>
  );
}

/** Replaces the composer once the trainer-client relationship ends (§1.3/1). */
export function ArchivedComposerNotice() {
  const t = useTranslations("chat");
  return (
    <div
      className="flex items-center gap-2.5 mx-5 mb-4 px-4 py-3.5 rounded-[var(--r-control)] shrink-0"
      style={{ background: "var(--nested)", color: "var(--text-2)" }}
    >
      <span aria-hidden="true" className="material-symbols-rounded text-[20px]">lock</span>
      <span className="text-[12.5px] font-semibold">{t("archivedNotice")}</span>
    </div>
  );
}
