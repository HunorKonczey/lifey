"use client";

import { useState } from "react";
import { Card } from "../../Card";
import { TextField } from "../../field/TextField";
import { PasswordField } from "../../field/PasswordField";
import { NumberField } from "../../field/NumberField";
import { TimeField } from "../../field/TimeField";
import { TextArea } from "../../field/TextArea";
import { ReadOnlyField } from "../../field/ReadOnlyField";

/** D-W0.9 — every field in every state: default, error, disabled, read-only,
 *  a number field with a unit and steppers, a time field with quick chips. */
export function FieldsSection() {
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [grams, setGrams] = useState(166.7);
  const [time, setTime] = useState("17:30");
  const [note, setNote] = useState("");

  return (
    <Card className="flex flex-col gap-4 max-w-md">
      <TextField label="Name" placeholder="Anna Kovács" value={name} onChange={(e) => setName(e.target.value)} />
      <TextField label="With an error" defaultValue="not-an-email" error="Legalább 8 karakter kell (most 6)." />
      <TextField label="Disabled" defaultValue="Can't touch this" disabled />
      <PasswordField label="Password" value={password} onChange={(e) => setPassword(e.target.value)} />
      <NumberField label="Protein" unit="g" value={grams} onChange={setGrams} step={0.1} min={0} />
      <TimeField label="Reminder" value={time} onChange={setTime} quickTimes={["17:30", "18:30"]} />
      <TextArea label="Notes" value={note} onChange={(e) => setNote(e.target.value)} placeholder="Optional" />
      <ReadOnlyField label="Client" value="Kliens · csak olvasható" />
    </Card>
  );
}
