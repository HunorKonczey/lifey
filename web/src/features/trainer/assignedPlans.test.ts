import { describe, expect, it } from "vitest";
import { planItems, programStatus } from "./assignedPlans";
import type { AssignmentListItemResponse, ProgramAssignmentSummaryResponse } from "./types";

const program = (o: Partial<ProgramAssignmentSummaryResponse>) =>
  ({ id: 1, clientId: 1, programId: 5, programName: "4 hetes", startDate: "2026-09-08", endDate: "2026-10-05", doneCount: 3, missedCount: 0, remainingCount: 5, cancelledAt: null, ...o }) as ProgramAssignmentSummaryResponse;
const single = (id: number, type: "TEMPLATE" | "RECIPE", at: string) => ({ id, contentType: type, sourceId: id, copiedId: 0, assignedAt: at }) as AssignmentListItemResponse;

describe("programStatus", () => {
  it("is scheduled before the start, active inside, done after the end or with nothing left", () => {
    expect(programStatus(program({}), "2026-09-01")).toBe("SCHEDULED");
    expect(programStatus(program({}), "2026-09-20")).toBe("ACTIVE");
    expect(programStatus(program({}), "2026-10-06")).toBe("DONE");
    expect(programStatus(program({ remainingCount: 0 }), "2026-09-20")).toBe("DONE");
  });
});

describe("planItems", () => {
  const name = (k: string, id: number) => `${k}${id}`;
  it("lists live programs first, then singles newest first, and drops cancelled programs", () => {
    const items = planItems(
      [single(1, "TEMPLATE", "2026-09-10T08:00:00Z"), single(2, "RECIPE", "2026-09-20T08:00:00Z")],
      [program({ id: 7, missedCount: 2 }), program({ id: 8, cancelledAt: "2026-09-12T00:00:00Z" })],
      name,
      "2026-09-25",
    );
    expect(items.map((i) => `${i.kind}:${i.id}`)).toEqual(["PROGRAM:7", "RECIPE:2", "TEMPLATE:1"]);
    expect(items[0]).toMatchObject({ status: "ACTIVE", missed: 2, to: "2026-10-05" });
    expect(items[1]).toMatchObject({ name: "RECIPE2", from: "2026-09-20", status: "ACTIVE" });
  });
});
