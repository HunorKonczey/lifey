import { describe, it, expect } from "vitest";
import { parseFrame } from "./chat-stream";

describe("parseFrame", () => {
  it("reads the event name, the id and the JSON payload", () => {
    const frame = parseFrame('event: message\nid: 4310\ndata: {"conversationId":12}');

    expect(frame).toEqual({ name: "message", id: "4310", data: { conversationId: 12 } });
  });

  it("defaults to the `message` event when the server omits the name", () => {
    // The SSE spec's default, and what an `id`-only frame would be.
    expect(parseFrame('data: {"a":1}')?.name).toBe("message");
  });

  it("leaves the cursor alone for a frame without an id", () => {
    // Read receipts deliberately carry no id, so Last-Event-ID keeps meaning
    // "the newest message I have".
    expect(parseFrame('event: read\ndata: {"conversationId":12}')?.id).toBeNull();
  });

  it("gives a typing frame no id either — it isn't a message at all", () => {
    const frame = parseFrame('event: typing\ndata: {"conversationId":12,"userId":88}');

    expect(frame).toEqual({ name: "typing", id: null, data: { conversationId: 12, userId: 88 } });
  });

  it("ignores heartbeat comments", () => {
    expect(parseFrame(": ping")).toBeNull();
  });

  it("joins multi-line data the way the wire format splits it", () => {
    expect(parseFrame('data: {"a":\ndata: 1}')?.data).toEqual({ a: 1 });
  });

  it("strips exactly one leading space after the colon, not more", () => {
    expect(parseFrame('event:  read\ndata: {}')?.name).toBe(" read");
    expect(parseFrame("event:read\ndata: {}")?.name).toBe("read");
  });

  it("survives a payload that isn't JSON instead of throwing into the read loop", () => {
    expect(parseFrame("event: message\ndata: not json")).toEqual({
      name: "message",
      id: null,
      data: null,
    });
  });
});
