"use client";

import { useState } from "react";
import { Button } from "../../Button";
import { Card } from "../../Card";
import { Checkbox } from "../../Checkbox";
import { Drawer } from "../../overlay/Drawer";
import { TextField } from "../../field/TextField";

/** D-W0.13 — Drawer (right-side panel, sticky header/footer, a full-height
 *  Sheet under 768px) with the unsaved-changes guard: check "Make it dirty"
 *  first to see Esc/scrim/× ask before closing (the `trainer-011` bug was a
 *  schedule drawer that skipped this and closed outright). */
export function DrawerSection() {
  const [open, setOpen] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [note, setNote] = useState("");

  return (
    <Card className="flex flex-wrap items-center gap-4">
      <Button onClick={() => setOpen(true)}>Open drawer</Button>
      <Checkbox checked={dirty} onChange={setDirty} label="Make it dirty" />
      <Drawer
        open={open}
        onClose={() => setOpen(false)}
        width={480}
        overline="Client"
        title="Edit note"
        isDirty={dirty}
        footer={
          <>
            <Button variant="secondary" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button
              onClick={() => {
                setDirty(false);
                setOpen(false);
              }}
            >
              Save
            </Button>
          </>
        }
      >
        <TextField label="Note" value={note} onChange={(e) => setNote(e.target.value)} />
      </Drawer>
    </Card>
  );
}
