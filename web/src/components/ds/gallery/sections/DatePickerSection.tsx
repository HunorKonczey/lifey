"use client";

import { useState } from "react";
import { Card } from "../../Card";
import { CalendarPopover } from "../../date/CalendarPopover";
import { DateFields } from "../../date/DateFields";
import { DateButton } from "../../date/DateButton";

/** D-W0.10 — the calendar grid (today filled, selection ring, data dots,
 *  disabled future days, keyboard) and typed segments in locale order. */
export function DatePickerSection() {
  const [date, setDate] = useState(new Date());
  const [birthDate, setBirthDate] = useState<Date | null>(null);
  const [open, setOpen] = useState(true);

  const loggedDays = [3, 5, 8, 12, 20];

  return (
    <div className="flex flex-wrap gap-6">
      <Card className="flex flex-col gap-3">
        <DateButton value={date} onClick={() => setOpen((o) => !o)} />
        {open && (
          <CalendarPopover
            value={date}
            onChange={setDate}
            disableFuture
            hasData={(d) => loggedDays.includes(d.getDate()) && d.getMonth() === date.getMonth()}
          />
        )}
      </Card>
      <Card className="max-w-xs">
        <DateFields label="Birth date" value={birthDate} onChange={setBirthDate} />
      </Card>
    </div>
  );
}
