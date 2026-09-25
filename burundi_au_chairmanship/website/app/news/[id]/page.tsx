import Link from "next/link";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { api, media, youtubeId } from "@/lib/api";
import { excerpt, fmtDate, getLang, paragraphs, t, tr } from "@/lib/i18n";
import { Crumbs, SectionHead } from "@/components/ui";
import { ArticleCard } from "../ArticleCard";

type Params = Promise<{ id: string }>;

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { id } = await params;
  const lang = await getLang();
  const a = await api.article(id);
  if (!a) return { title: "Not found" };
  const title = tr(a, "title", lang);
  const description = excerpt(tr(a, "content", lang), 30);
  const img = media(a.image);
  return { title, description, openGraph: { title, description, type: "article", images: img ? [img] : undefined } };
}

export default async function ArticlePage({ params }: { params: Params }) {
  const { id } = await params;
  const lang = await getLang();
  const a = await api.article(id);
  if (!a) notFound();
  const more = (await api.articles({ category: a.category?.id, page_size: 4 })).results.filter((x) => x.id !== a.id).slice(0, 3);
  const body = paragraphs(tr(a, "content", lang));
  const words = body.reduce((n, b) => n + b.lines.join(" ").split(/\s+/).length, 0);
  const minutes = Math.max(1, Math.round(words / 200));
  const url = `https://burundi4africa.com/news/${a.id}`;
  const title = tr(a, "title", lang);
  const extra = a.media.filter((m) => m.media_type === "video" ? m.video_url : m.image);
  const share = [
    ["X", `https://x.com/intent/tweet?url=${encodeURIComponent(url)}&text=${encodeURIComponent(title)}`, "M4 4h4.6L20 20h-4.6zM19.5 4l-6.4 7M10.9 13L4.5 20"],
    ["Facebook", `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`, "M14.5 21v-7.5h3l.5-3.5h-3.5V8.2c0-1 .4-1.7 1.8-1.7H18V3.4c-.4 0-1.5-.2-2.8-.2-2.8 0-4.5 1.7-4.5 4.7V10H7.5v3.5h3.2V21"],
    ["WhatsApp", `https://wa.me/?text=${encodeURIComponent(`${title} ${url}`)}`, "M3.5 20.5l1.3-4.2A8.5 8.5 0 1 1 8 19.3zM9 8.5c.3-.6.6-.6 1-.6h.4l1 2.2-.7 1c.5 1.1 1.4 2 2.5 2.5l1-.7 2.2 1v.4c0 .4 0 .7-.6 1-.8.5-1.8.5-2.8.1a8 8 0 0 1-4.2-4.2c-.4-1-.4-2 0-2.7z"],
  ] as const;
  const shareEl = (
    <div className="row" style={{ gap: 8 }}>
      <span className="sc muted" style={{ marginRight: 6, fontSize: 15 }}>{t(lang, "Share", "Partager")}</span>
      {share.map(([name, href, d]) => (
        <a key={name} className="icon-btn" href={href} target="_blank" rel="noopener" aria-label={t(lang, `Share on ${name}`, `Partager sur ${name}`)}>
          <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>
        </a>
      ))}
    </div>
  );

  return (
    <>
      <section style={{ padding: "64px 0 48px" }}>
        <div className="wrap grid" style={{ rowGap: 0 }}>
          <div className="span-12"><Crumbs lang={lang} items={[[t(lang, "Newsroom", "Actualités"), "/news"], [a.category ? tr(a.category, "name", lang) : a.author, a.category ? `/news?category=${a.category.id}` : undefined]]} /></div>
          <p className="span-12 eyebrow" style={{ marginTop: 36, fontSize: 17 }}>{a.category ? tr(a.category, "name", lang) : a.author} · <time dateTime={a.publish_date}>{fmtDate(a.publish_date, lang)}</time></p>
          <h1 className="span-10 h1 h1--md" style={{ marginTop: 18, fontSize: "clamp(36px, 4.4vw, 60px)", lineHeight: 1.06 }}>{title}</h1>
          <p className="span-8 display" style={{ marginTop: 24, fontSize: "clamp(20px, 1.9vw, 26px)", lineHeight: 1.4, color: "#33443A" }}>{excerpt(body[0]?.lines.join(" ") ?? "", 40)}</p>
          <div className="span-12 between" style={{ marginTop: 36, padding: "18px 0", borderTop: "1px solid var(--line-2)", borderBottom: "1px solid var(--line-2)", alignItems: "center" }}>
            <div className="row" style={{ gap: 14 }}>
              <img src="/img/seal.png" alt="" width={48} height={48} />
              <span className="stack" style={{ gap: 0, lineHeight: 1.35 }}><span className="bold">{a.author}</span><span className="small muted">{t(lang, "Published in the newsroom and the B4Africa app", "Publié dans les actualités et l’app B4Africa")}</span></span>
              <span aria-hidden="true" style={{ width: 1, height: 36, margin: "0 8px", background: "var(--line-2)" }} />
              <span className="row muted" style={{ gap: 8, fontSize: 15 }}>
                <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="8.5" /><path d="M12 7.5V12l3 2" /></svg>
                {t(lang, `${minutes} min read`, `${minutes} min de lecture`)}
              </span>
            </div>
            {shareEl}
          </div>
        </div>
      </section>

      {a.image && (
        <section>
          <figure className="wrap stack" style={{ gap: 14 }}>
            <div className="fig" style={{ maxHeight: 620 }}><img src={media(a.image)} alt={title} style={{ maxHeight: 620 }} /></div>
            {a.media[0]?.caption && <figcaption className="caption" style={{ marginTop: 0 }}>{tr(a.media[0], "caption", lang)}</figcaption>}
          </figure>
        </section>
      )}

      <section style={{ padding: "72px 0 104px" }}>
        <div className="wrap grid" style={{ alignItems: "start" }}>
          <aside aria-label={t(lang, "About this story", "À propos de cet article")} className="span-3 stack" style={{ gap: 36, position: "sticky", top: 112 }}>
            <div className="stack" style={{ gap: 12 }}>
              <span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "Filed under", "Rubrique")}</span>
              <div className="chips">
                {a.category && <Link className="chip" href={`/news?category=${a.category.id}`}>{tr(a.category, "name", lang)}</Link>}
                <span className="chip" style={{ fontWeight: 400 }}>{a.content_type === "news" ? t(lang, "News", "Actualité") : "Article"}</span>
              </div>
            </div>
            <div className="stack" style={{ gap: 12, paddingTop: 16, borderTop: "2px solid var(--ink)" }}>
              <span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "In the B4Africa app", "Dans l’app B4Africa")}</span>
              <div className="stack" style={{ gap: 8, fontSize: 15, fontWeight: 700 }}>
                <a className="row no-ul" href={`/articles/${a.id}/share/`} style={{ height: 48, padding: "0 18px", borderRadius: 999, background: "var(--ivory)", gap: 12 }}>{t(lang, "Open in the app", "Ouvrir dans l’app")}<span aria-hidden="true" style={{ marginLeft: "auto" }}>↗</span></a>
                <a className="row no-ul" href="/app" style={{ height: 48, padding: "0 18px", borderRadius: 999, background: "var(--ivory)", gap: 12 }}>{t(lang, "Get the app", "Télécharger l’app")}<span aria-hidden="true" style={{ marginLeft: "auto" }}>↗</span></a>
              </div>
            </div>
            <div className="card card--ivory" style={{ gap: 6 }}>
              <span className="eyebrow" style={{ fontSize: 14 }}>{t(lang, "About", "À propos")}</span>
              <h2 className="h3 h3--sm" style={{ fontSize: 22 }}>{a.author}</h2>
              <dl className="stack" style={{ gap: 14, marginTop: 10 }}>
                <div><dt className="sc small muted">{t(lang, "Published", "Publié le")}</dt><dd style={{ fontSize: 15 }}>{fmtDate(a.publish_date, lang)}</dd></div>
                {a.category && <div><dt className="sc small muted">{t(lang, "Topic", "Thème")}</dt><dd style={{ fontSize: 15 }}>{tr(a.category, "name", lang)}</dd></div>}
                <div><dt className="sc small muted">{t(lang, "Views", "Lectures")}</dt><dd style={{ fontSize: 15 }}>{a.view_count.toLocaleString(lang === "fr" ? "fr-FR" : "en-GB")}</dd></div>
              </dl>
            </div>
          </aside>

          <article className="span-7 start-5 prose" style={{ color: "#33443A", fontSize: 19, lineHeight: 1.8 }}>
            {body.map((b, i) =>
              b.type === "ul" ? (
                <ul key={i}>{b.lines.map((l, j) => <li key={j}>{l}</li>)}</ul>
              ) : (
                <p key={i}>
                  {i === 0 && <span aria-hidden="true" style={{ float: "left", margin: "8px 14px 0 0", fontFamily: "var(--display)", fontSize: 112, fontWeight: 500, lineHeight: 0.82, color: "var(--gold-ink)" }}>{b.lines[0].charAt(0)}</span>}
                  {i === 0 ? b.lines[0].slice(1) : b.lines[0]}
                  {b.lines.slice(1).map((l, j) => <span key={j}><br />{l}</span>)}
                </p>
              ),
            )}
            {extra.length > 0 && (
              <div className="stack" style={{ gap: 24, marginTop: 40 }}>
                {extra.map((m) => {
                  const yt = m.media_type === "video" ? youtubeId(m.video_url) : "";
                  return (
                    <figure key={m.id} className="stack" style={{ gap: 10 }}>
                      {m.media_type === "video" ? (
                        yt ? <div className="embed"><iframe src={`https://www.youtube.com/embed/${yt}`} title={tr(m, "caption", lang) || title} allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowFullScreen /></div>
                           : <a className="btn btn--outline btn--md" href={m.video_url} target="_blank" rel="noopener" style={{ alignSelf: "flex-start" }}>{t(lang, "Watch the video", "Voir la vidéo")} ↗</a>
                      ) : (
                        <span className="fig"><img src={media(m.image)} alt={tr(m, "caption", lang)} loading="lazy" /></span>
                      )}
                      {tr(m, "caption", lang) && <figcaption className="caption" style={{ marginTop: 0 }}>{tr(m, "caption", lang)}</figcaption>}
                    </figure>
                  );
                })}
              </div>
            )}
          </article>

          <div className="span-8 start-5 between" style={{ marginTop: 48, paddingTop: 24, borderTop: "1px solid var(--line-2)", alignItems: "center" }}>
            <Link className="btn btn--outline btn--md" href="/news">← {t(lang, "Back to the Newsroom", "Retour aux actualités")}</Link>
            {shareEl}
          </div>
        </div>
      </section>

      {more.length > 0 && (
        <section className="sec sec--ivory">
          <div className="wrap stack stack--lg">
            <SectionHead eyebrow={t(lang, "Keep reading", "À lire aussi")} title={t(lang, "More stories", "Autres articles")} more={t(lang, "All news in the Newsroom", "Toutes les actualités")} moreHref="/news" />
            <div className="cols cols-3" style={{ gap: 24 }}>
              {more.map((x) => <ArticleCard key={x.id} a={x} lang={lang} />)}
            </div>
          </div>
        </section>
      )}
    </>
  );
}
