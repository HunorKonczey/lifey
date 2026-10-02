import { describe, expect, it } from "vitest";
import { gridItemVars } from "./PageGrid";

describe("gridItemVars", () => {
  it("emits one custom property per breakpoint that was given", () => {
    expect(gridItemVars({ base: 4, md: 8, xl: 8 }, { md: 2 })).toEqual({
      "--span-base": 4,
      "--span-md": 8,
      "--span-xl": 8,
      "--order-md": 2,
    });
  });

  it("emits nothing when neither span nor order is given (full row, source order)", () => {
    expect(gridItemVars()).toEqual({});
  });

  it("keeps an explicit zero (order 0 is a real value, not 'unset')", () => {
    expect(gridItemVars(undefined, { xl: 0 })).toEqual({ "--order-xl": 0 });
  });
});
