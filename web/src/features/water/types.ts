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
  volumeLiters: number;
  sourceId?: number;
}

export interface WaterSourceRequest {
  name: string;
  volumeLiters: number;
}
