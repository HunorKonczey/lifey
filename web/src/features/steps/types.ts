export interface DailyStepCountResponse {
  id: number;
  date: string; // LocalDate → yyyy-MM-dd
  steps: number;
}

export interface DailyStepCountRequest {
  date: string;
  steps: number;
}
