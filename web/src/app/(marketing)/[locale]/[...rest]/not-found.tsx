/**
 * The boundary the catch-all's `notFound()` lands on. A `not-found.tsx` beside a *root* layout (`../not-found.tsx`) does
 * not render inside it, so since the marketing tree became its own root layout (LIF-142) the branded 404 is re-exported
 * from one level down, where the header, footer and theme of `../layout.tsx` still wrap it.
 */
export { default } from "../not-found";
