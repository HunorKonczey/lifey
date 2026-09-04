// Mirrors backend/src/main/java/com/lifey/trainer/request/dto/TrainerRequestResponse.java
// and TrainerRequestRequest.java (docs/landing_page/66-trainer-billing-web-plan.md §2).

export type TrainerRequestStatus = "PENDING" | "APPROVED" | "REJECTED";

export interface TrainerRequestResponse {
  id: number;
  status: TrainerRequestStatus;
  motivation: string | null;
  clientCount: number | null;
  createdAt: string;
  decidedAt: string | null;
}

export interface TrainerRequestRequest {
  motivation?: string;
  clientCount?: number;
  signupSource?: string;
}

/** The superadmin queue's richer shape — includes the requester's identity. */
export interface SuperAdminTrainerRequestResponse {
  id: number;
  userId: number;
  userEmail: string;
  status: TrainerRequestStatus;
  motivation: string | null;
  clientCount: number | null;
  signupSource: string | null;
  createdAt: string;
  decidedAt: string | null;
}
