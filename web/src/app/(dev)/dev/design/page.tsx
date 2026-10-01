import { notFound } from "next/navigation";
import { GalleryClient } from "./GalleryClient";

/** Every `ds` component with fixture data (D-W0.12) — the debug design
 *  gallery, mobile's counterpart is the debug gallery from R0.11. Gone in a
 *  production build, same as `next build && next start` verifies. */
export default function DevDesignPage() {
  if (process.env.NODE_ENV === "production") notFound();
  return <GalleryClient />;
}
