export interface WeightResponse {
  id: number;
  date: string; // LocalDate → yyyy-MM-dd
  weight: number;
  /** When the weigh-in was taken (ISO instant); the day's `date` says which day. Absent from an older server. */
  recordedAt?: string | null;
  /** Optional free text, at most 280 characters. */
  note?: string | null;
}

export const WEIGHT_NOTE_MAX = 280;

export interface WeightRequest {
  date: string;
  weight: number;
  /** When it was taken; absent = now. */
  recordedAt?: string;
  note?: string;
}
