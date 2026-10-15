import Image from "next/image";
import { getLocale, getTranslations } from "next-intl/server";
import { BrowserWindowFrame } from "./BrowserWindowFrame";

/**
 * A capture of the real product, in a browser-window frame (LIF-120, docs/landing_page/72 W12) - what the hero-adjacent
 * value blocks used to reproduce in HTML/CSS (`design/Lifey Landing.dc.html` L10-L12).
 *
 * The files are `public/marketing/shots/<shot>-<locale>-<theme>.webp`, written by `scripts/marketing-demo/capture.mjs` from the
 * seeded demo dataset; regenerate them whenever the trainer pages change. There is one per language and one per theme, so the
 * picture matches both the page's language and its theme: the dark and the light image are both in the markup and the stylesheet
 * shows one (`.product-shot-*` in globals.css). Both are lazy, and a lazy image that is not displayed is not fetched.
 *
 * A Server Component with no client JS - `next/image` here only sizes and serves the file.
 */
const SHOTS = {
  clients: {
    width: 2240,
    height: 1400,
    url: "lifey.hu/admin/clients/szabo-anna",
    alt: "clientsAlt",
  },
  program: { width: 2640, height: 1520, url: "lifey.hu/admin/programs/ero-5x5", alt: "programAlt" },
  chat: { width: 2240, height: 1400, url: "lifey.hu/admin/chat", alt: "chatAlt" },
} as const;

export type ShotName = keyof typeof SHOTS;

export async function ProductShot({ shot }: { shot: ShotName }) {
  const locale = await getLocale();
  const t = await getTranslations("home.shots");
  const { width, height, url, alt } = SHOTS[shot];

  return (
    <BrowserWindowFrame url={url}>
      {(["dark", "light"] as const).map((theme) => (
        <Image
          key={theme}
          className={`product-shot-${theme} block h-auto w-full`}
          src={`/marketing/shots/${shot}-${locale}-${theme}.webp`}
          width={width}
          height={height}
          sizes="(min-width: 1024px) 640px, calc(100vw - 48px)"
          alt={t(alt)}
        />
      ))}
    </BrowserWindowFrame>
  );
}
