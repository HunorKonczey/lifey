export interface WeightResponse {
  id: number;
  date: string; // LocalDate → yyyy-MM-dd
  weight: number;
}

export interface WeightRequest {
  date: string;
  weight: number;
}
