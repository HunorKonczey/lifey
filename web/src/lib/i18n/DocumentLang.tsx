"use client";

import { useEffect } from "react";

/**
 * Keeps `<html lang>` in step with the language the page is actually shown in. The root layout cannot know it —
 * the signed-in app picks its language on the client (the setting, else `navigator.language`) and the marketing
 * tree takes it from the URL segment — so it renders `lang="en"` and this corrects it after hydration. Screen readers
 * and the browser's translate offer read the attribute from the live DOM, so they see the right one.
 */
export function DocumentLang({ locale }: { locale: string }) {
  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);
  return null;
}
