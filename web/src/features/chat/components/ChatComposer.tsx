"use client";

import { useLayoutEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { MAX_MESSAGE_LENGTH, isMessageSendable, trimMessageForSend } from "../thread";

/** ~5 text rows before the textarea stops growing and scrolls internally. */
const MAX_ROWS_PX = 132;

interface ChatComposerProps {
  onSend: (body: string) => void;
  /** Set while a send is in flight; the composer stays usable, only the button waits. */
  disabled?: boolean;
}

export function ChatComposer({ onSend, disabled = false }: ChatComposerProps) {
  const t = useTranslations("chat");
  const [value, setValue] = useState("");
  const [focused, setFocused] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Grow with the content: reset to auto first, or the box can only ever get
  // taller (scrollHeight never shrinks below the current height).
  useLayoutEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, MAX_ROWS_PX)}px`;
  }, [value]);

  const sendable = isMessageSendable(value) && !disabled;
  const overLimit = value.trim().length > MAX_MESSAGE_LENGTH;

  const submit = () => {
    const body = trimMessageForSend(value);
    if (!body || !sendable) return;
    onSend(body);
    setValue("");
  };

  return (
    <div className="flex flex-col px-5 pb-4 shrink-0">
      <div className="flex items-end gap-2.5">
        <textarea
          ref={textareaRef}
          rows={1}
          value={value}
          onChange={(e) => setValue(e.target.value)}
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
            background: "var(--surface-container)",
            color: "var(--on-surface)",
            borderRadius: "var(--r-input)",
            maxHeight: MAX_ROWS_PX,
          }}
        />
        <button
          onClick={submit}
          disabled={!sendable}
          aria-label={t("send")}
          title={t("send")}
          className="w-[46px] h-[46px] shrink-0 rounded-[15px] flex items-center justify-center transition-opacity disabled:opacity-40"
          style={{ background: "var(--primary)", color: "#161611" }}
        >
          <span className="material-symbols-rounded text-[22px]" style={{ fontVariationSettings: "'FILL' 1" }}>
            send
          </span>
        </button>
      </div>

      <div className="flex items-center gap-3 mt-1.5 ml-1 min-h-[15px]">
        {focused && (
          <span className="text-[10.5px] font-semibold" style={{ color: "var(--muted)" }}>
            {t("keyboardHint")}
          </span>
        )}
        {overLimit && (
          <span className="text-[10.5px] font-extrabold ml-auto mr-1" style={{ color: "var(--error)" }}>
            {t("tooLong", { max: MAX_MESSAGE_LENGTH })}
          </span>
        )}
      </div>
    </div>
  );
}

/** Replaces the composer once the trainer-client relationship ends (§1.3/1). */
export function ArchivedComposerNotice() {
  const t = useTranslations("chat");
  return (
    <div
      className="flex items-center gap-2.5 mx-5 mb-4 px-4 py-3.5 rounded-[var(--r-input)] shrink-0"
      style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
    >
      <span className="material-symbols-rounded text-[20px]">lock</span>
      <span className="text-[12.5px] font-semibold">{t("archivedNotice")}</span>
    </div>
  );
}
