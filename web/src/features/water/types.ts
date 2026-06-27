export interface WaterSourceResponse {
  id: number;
  name: string;
  volumeLiters: number;
}

export interface WaterEntryResponse {
  id: number;
  consumedAt: string; // Instant → ISO string
  volumeLiters: number;
  sourceId: number | null;
  sourceName: string | null;
}

export interface WaterEntryRequest {
  consumedAt: string; // Instant, must be past or present
  volumeLiters: number;
  sourceId?: number | null;
}

export interface WaterSourceRequest {
  name: string;
  volumeLiters: number;
}
