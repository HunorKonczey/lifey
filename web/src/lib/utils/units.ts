// Metric is canonical everywhere in the backend (cm, kg) — these only convert
// for imperial-unit display/input, mirroring the existing weight-entry form's
// unit-system awareness (see docs/21-onboarding-user-details-plan.md).

const CM_PER_INCH = 2.54;
const KG_PER_LB = 0.45359237;

export function cmToFeetInches(cm: number): { feet: number; inches: number } {
  const totalInches = cm / CM_PER_INCH;
  let feet = Math.floor(totalInches / 12);
  let inches = Math.round(totalInches - feet * 12);
  if (inches === 12) {
    feet += 1;
    inches = 0;
  }
  return { feet, inches };
}

export function feetInchesToCm(feet: number, inches: number): number {
  return Math.round(((feet || 0) * 12 + (inches || 0)) * CM_PER_INCH * 10) / 10;
}

export function kgToLb(kg: number): number {
  return Math.round((kg / KG_PER_LB) * 10) / 10;
}

export function lbToKg(lb: number): number {
  return Math.round(lb * KG_PER_LB * 10) / 10;
}
