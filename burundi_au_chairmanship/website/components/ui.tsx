import Link from "next/link";
import type { ReactNode } from "react";
import type { Lang } from "@/lib/types";
import { t } from "@/lib/i18n";

/** Eyebrow + heading + optional "more" link, the header of every section. */
export function SectionHead({ eyebrow, title, more, moreHref, size = "h2", light = false }: {
  eyebrow?: ReactNode; title: ReactNode; more?: ReactNode; moreHref?: string; size?: "h2" | "h2 h2--xl" | "h2 h2--md"; light?: boolean;
}) {
  return (
    <div className="between">
      <div className="stack" style={{ gap: 6 }}>
        {eyebrow && <span className={`eyebrow${light ? " eyebrow--gold" : ""}`}>{eyebrow}</span>}
        <h2 className={size}>{title}</h2>
      </div>
      {more && moreHref && <Link className="more arrow" href={moreHref}>{more}</Link>}
    </div>
  );
}

export function Crumbs({ lang, items }: { lang: Lang; items: Array<[string, string?]> }) {
  return (
    <nav aria-label="Breadcrumb" className="crumbs">
      <Link href="/">{t(lang, "Home", "Accueil")}</Link>
      {items.map(([label, href], i) => (
        <span key={i} style={{ display: "contents" }}>
          <span aria-hidden="true">/</span>
          {href ? <Link href={href}>{label}</Link> : <span aria-current="page">{label}</span>}
        </span>
      ))}
    </nav>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="empty">{children}</p>;
}

export function PlayIcon() {
  return (
    <span className="play">
      <svg width="30" height="30" viewBox="0 0 24 24" fill="#0F2A1B"><path d="M8 5.5v13l11-6.5z" /></svg>
    </span>
  );
}

/** Stroke icon from a 24×24 path, matching the design's inline SVGs. */
export function Ico({ d, size = 22, stroke = "#0F2A1B" }: { d: string; size?: number; stroke?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={stroke} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d} /></svg>
  );
}

export const ICONS = {
  doc: "M4 3h16v18H4zM8 8h8M8 12h8M8 16h5",
  passport: "M5 3h14v18H5zM12 10m-3 0a3 3 0 1 0 6 0a3 3 0 1 0-6 0M9 16h6",
  send: "M3 12l18-8-6 17-3-7zM12 14l9-10",
  link: "M6 18m-2 0a2 2 0 1 0 4 0a2 2 0 1 0-4 0M18 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0-4 0M8 18h5a3 3 0 0 0 0-6h-2a3 3 0 0 1 0-6h5",
  warn: "M12 3l9.5 17h-19zM12 10v4M12 17.5v.01",
  drop: "M12 3s6 7 6 11a6 6 0 0 1-12 0c0-4 6-11 6-11z",
  rise: "M3 17l6-6 4 4 8-8M15 7h6v6",
  shield: "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z",
  phone: "M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2",
  mail: "M3 5h18v14H3zM3 7l9 6 9-6",
  pin: "M12 21s-7-6.5-7-11a7 7 0 0 1 14 0c0 4.5-7 11-7 11zM12 10m-2.5 0a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0",
  clock: "M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 7v5l3 2",
  calendar: "M3 5h18v16H3zM3 10h18M8 3v4M16 3v4",
  play: "M12 12m-10 0a10 10 0 1 0 20 0a10 10 0 1 0-20 0M10 8l6 4-6 4z",
  book: "M2 4h6a4 4 0 0 1 4 4v13a3 3 0 0 0-3-3H2zM22 4h-6a4 4 0 0 0-4 4v13a3 3 0 0 1 3-3h7z",
  image: "M3 5h18v14H3zM3 15l5-5 4 4 3-3 6 6M16 9m-1.5 0a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0-3 0",
  download: "M12 4v11M7 10l5 5 5-5M5 20h14",
  globe: "M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0-18 0M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18",
  users: "M9 11m-3 0a3 3 0 1 0 6 0a3 3 0 1 0-6 0M3 20a6 6 0 0 1 12 0M17 11m-2 0a2 2 0 1 0 4 0a2 2 0 1 0-4 0M15 20a5 5 0 0 1 6-4.5",
  bank: "M3 10l9-6 9 6M5 10v9M9 10v9M15 10v9M19 10v9M3 19h18",
  arrow: "M5 12h14M13 6l6 6-6 6",
};
