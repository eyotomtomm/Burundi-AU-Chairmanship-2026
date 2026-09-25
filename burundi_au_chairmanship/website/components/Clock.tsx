"use client";
import { useEffect, useState } from "react";

const fmt = (tz: string) =>
  new Intl.DateTimeFormat("en-GB", { timeZone: tz, hour: "2-digit", minute: "2-digit" }).format(new Date());

export function Clock() {
  const [now, setNow] = useState<{ addis: string; gitega: string } | null>(null);
  useEffect(() => {
    const tick = () => setNow({ addis: fmt("Africa/Addis_Ababa"), gitega: fmt("Africa/Bujumbura") });
    tick();
    const id = setInterval(tick, 30_000);
    return () => clearInterval(id);
  }, []);
  return (
    <span className="clock" suppressHydrationWarning>
      Addis Ababa <b>{now?.addis ?? "--:--"}</b> · Gitega <b>{now?.gitega ?? "--:--"}</b>
    </span>
  );
}
