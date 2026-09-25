import Link from "next/link";
import type { Article, Lang } from "@/lib/types";
import { media } from "@/lib/api";
import { excerpt, fmtDate, tr } from "@/lib/i18n";

/** The 3-up newsroom card: image, category · date, title, 2-line summary, author. */
export function ArticleCard({ a, lang, fallback = "/img/au-hq-duotone.jpg" }: { a: Article; lang: Lang; fallback?: string }) {
  return (
    <Link className="card card--flush news-card" href={`/news/${a.id}`} style={{ minHeight: 470 }}>
      <img src={media(a.medium_url || a.image) || fallback} alt="" loading="lazy" />
      <div className="card-body" style={{ flex: 1, padding: "22px 26px 24px", gap: 10 }}>
        <Meta a={a} lang={lang} />
        <span className="h3 h3--sm" style={{ fontSize: 25 }}>{tr(a, "title", lang)}</span>
        <span className="small muted" style={{ fontSize: 15, lineHeight: 1.6 }}>{excerpt(tr(a, "content", lang), 26)}</span>
        <span className="push small muted" style={{ fontSize: 13 }}>{a.author}</span>
      </div>
    </Link>
  );
}

export function Meta({ a, lang }: { a: Article; lang: Lang }) {
  return (
    <span className="row small muted" style={{ gap: 8, alignItems: "baseline" }}>
      {a.category && <><span className="eyebrow" style={{ fontSize: 15 }}>{tr(a.category, "name", lang)}</span><span aria-hidden="true">·</span></>}
      <time dateTime={a.publish_date}>{fmtDate(a.publish_date, lang)}</time>
    </span>
  );
}
