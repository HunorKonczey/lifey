/** CHEST → "Chest", FULL_BODY → "Full body", SMITH_MACHINE → "Smith machine". */
export function humanizeEnum(value: string | null | undefined): string {
  if (!value) return "—";
  const lower = value.replace(/_/g, " ").toLowerCase();
  return lower.charAt(0).toUpperCase() + lower.slice(1);
}
