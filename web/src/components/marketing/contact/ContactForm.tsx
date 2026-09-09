"use client";

import { useState } from "react";
import { env } from "@/lib/env";

type Status = "idle" | "submitting" | "success" | "error";

/**
 * Posts straight to the backend's `POST /api/v1/contact` (65 Prompt 8, "the
 * existing mail path" — `com.lifey.mail.service.MailService.sendContactMessage`,
 * added alongside this). Deliberately a plain `fetch`, not the app's
 * `lib/api/client.ts` — that client is built around access tokens and a
 * 401-refresh flow, neither of which applies to an anonymous public form,
 * and the marketing tree avoids the app's Providers/React Query stack
 * entirely (65 D-W6). Field-level validation is native HTML5
 * (`required`/`type="email"`) rather than a hand-rolled error-message set —
 * one fewer thing to translate, and better default screen-reader behavior
 * than a custom implementation would get for free.
 */
export function ContactForm({
  locale,
  labels,
}: {
  locale: string;
  labels: {
    name: string;
    email: string;
    message: string;
    submit: string;
    sending: string;
    success: string;
    error: string;
  };
}) {
  const [status, setStatus] = useState<Status>("idle");

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const data = new FormData(form);
    setStatus("submitting");

    try {
      const res = await fetch(`${env.NEXT_PUBLIC_API_BASE_URL}/contact`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: data.get("name"),
          email: data.get("email"),
          message: data.get("message"),
          locale,
        }),
      });

      if (!res.ok) throw new Error(`status ${res.status}`);

      setStatus("success");
      form.reset();
    } catch {
      setStatus("error");
    }
  }

  if (status === "success") {
    return (
      <div
        className="rounded-lg p-6 md:p-7 flex items-center gap-3"
        style={{ background: "var(--surface)", border: "1px solid var(--outline)" }}
      >
        <span
          className="material-symbols-rounded text-2xl"
          style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}
        >
          check_circle
        </span>
        <p className="text-base font-semibold">{labels.success}</p>
      </div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="rounded-lg p-6 md:p-7 flex flex-col gap-4"
      style={{ background: "var(--surface)", border: "1px solid var(--outline)" }}
    >
      <div className="flex flex-col gap-1.5">
        <label htmlFor="contact-name" className="text-sm font-bold">
          {labels.name}
        </label>
        <input
          id="contact-name"
          name="name"
          type="text"
          required
          maxLength={100}
          className="h-12 rounded-md border border-outline px-3.5 text-base"
          style={{ background: "var(--bg)" }}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="contact-email" className="text-sm font-bold">
          {labels.email}
        </label>
        <input
          id="contact-email"
          name="email"
          type="email"
          required
          maxLength={254}
          className="h-12 rounded-md border border-outline px-3.5 text-base"
          style={{ background: "var(--bg)" }}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="contact-message" className="text-sm font-bold">
          {labels.message}
        </label>
        <textarea
          id="contact-message"
          name="message"
          required
          maxLength={2000}
          rows={5}
          className="rounded-md border border-outline px-3.5 py-3 text-base resize-y"
          style={{ background: "var(--bg)" }}
        />
      </div>

      {status === "error" && (
        <p className="text-sm font-semibold" style={{ color: "var(--secondary)" }}>
          {labels.error}
        </p>
      )}

      <button
        type="submit"
        disabled={status === "submitting"}
        className="h-13 rounded-pill text-sm font-extrabold disabled:opacity-60"
        style={{ background: "var(--primary)", color: "var(--bg)" }}
      >
        {status === "submitting" ? labels.sending : labels.submit}
      </button>
    </form>
  );
}
