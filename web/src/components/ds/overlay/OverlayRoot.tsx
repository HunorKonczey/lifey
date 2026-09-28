export const OVERLAY_ROOT_ID = "lifey-overlay-root";

/**
 * Mounted once near the app root (`Providers`) — every overlay (popover,
 * modal, drawer, toast) portals into this single node instead of
 * `document.body` directly, so z-order between them (D-W0.15: toast > modal
 * > drawer > popover > top bar) is plain CSS on siblings of one element
 * rather than independently-stacked portals guessing at each other's
 * z-index.
 */
export function OverlayRoot() {
  return <div id={OVERLAY_ROOT_ID} />;
}

export function getOverlayContainer(): HTMLElement {
  return document.getElementById(OVERLAY_ROOT_ID) ?? document.body;
}
