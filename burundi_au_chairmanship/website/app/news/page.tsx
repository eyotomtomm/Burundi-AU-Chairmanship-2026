import Link from "next/link";
import type { Metadata } from "next";
import { api, chairshipPosts, media } from "@/lib/api";
import { excerpt, fmtDate, getLang, t, tr } from "@/lib/i18n";
import { Crumbs, Empty, PlayIcon, SectionHead } from "@/components/ui";
import { ArticleCard, Meta } from "./ArticleCard";

export const metadata: Metadata = { title: "Newsroom" };

type Search = { category?: string; q?: string; page?: string };

export default async function Newsroom({ searchParams }: { searchParams: Promise<Search> }) {
  const lang = await getLang();
  const { category, q, page } = await searchParams;
  const pageNo = Math.max(1, Number(page) || 1);
  // The list endpoint has no text filter; search goes through /search/articles/ (max 20, unpaginated).
  const newsP = q
    ? api.searchArticles(q).then((r) => ({ count: r.length, next: null, previous: null, results: category ? r.filter((a) => String(a.category?.id) === category) : r }))
    : api.articles({ category, page: pageNo, page_size: 13 });
  const [news, categories, videos, magazines, albums, resources] = await Promise.all([
    newsP,
    api.categories(),
    api.videos({ page_size: 1 }),
    api.magazines(),
    api.albums(),
    api.resources(),
  ]);
  const chairship = await chairshipPosts(6);
  const frontPage = pageNo === 1 && !q;
  const lead = frontPage ? news.results[0] : undefined;
  const others = frontPage ? news.results.slice(1) : news.results;
  const side = others.slice(0, 3);
  const brief = others.slice(3, 8);
  const latest = frontPage ? others.slice(8) : others;
  // ponytail: the Embassy's own dispatches are recognised by author; a dedicated flag can replace this.
  const dispatches = news.results.filter((a) => /embass|ambassade/i.test(a.author));
  const documents = resources.results.filter((r) => r.category === "official_documents");
  const totalPages = Math.max(1, Math.ceil(news.count / 13));
  const href = (p: number) => {
    const s = new URLSearchParams();
    if (category) s.set("category", category);
    if (q) s.set("q", q);
    if (p > 1) s.set("page", String(p));
    const qs = s.toString();
    return `/news${qs ? `?${qs}` : ""}`;
  };
  const cat = categories.find((c) => String(c.id) === category);
  const video = videos.results[0];
  const magazine = magazines.results[0];
  const album = albums.results[0];

  return (
    <>
      <section style={{ padding: "56px 0 44px" }}>
        <div className="wrap stack" style={{ gap: 0 }}>
          <Crumbs lang={lang} items={[[t(lang, "Newsroom", "Actualités")]]} />
          <div className="between" style={{ marginTop: 28, padding: "12px 0", borderTop: "2px solid var(--ink)", borderBottom: "1px solid var(--line-2)", alignItems: "center" }}>
            <p className="sc bold" style={{ fontSize: 17 }}><time dateTime={new Date().toISOString().slice(0, 10)}>{fmtDate(new Date().toISOString(), lang, { weekday: "long" })}</time> · Addis Ababa</p>
            <p className="sc muted" style={{ fontSize: 15 }}>{t(lang, "Embassy dispatches · Ministry of Foreign Affairs · Official texts", "Dépêches de l’Ambassade · Ministère des Affaires étrangères · Textes officiels")}</p>
          </div>
          <div className="grid" style={{ padding: "26px 0 30px", alignItems: "end" }}>
            <h1 className="span-8 h1" style={{ fontSize: "clamp(56px, 9.4vw, 136px)", lineHeight: 1, letterSpacing: "-0.02em" }}><em className="hl">{t(lang, "Newsroom", "Actualités")}</em></h1>
            <p className="span-4 start-9 lede lede--sm" style={{ fontSize: 17 }}>
              {t(lang,
                "One newsroom for the Embassy’s own dispatches and the Ministry of Foreign Affairs’ news on Burundi’s year at the head of the African Union, with communiqués, speeches and publications alongside.",
                "Une seule salle de presse pour les dépêches de l’Ambassade et les nouvelles du Ministère des Affaires étrangères sur l’année du Burundi à la tête de l’Union africaine, avec communiqués, discours et publications.")}
            </p>
          </div>
          <div className="grid" style={{ paddingTop: 28, borderTop: "1px solid var(--line-2)", alignItems: "start" }}>
            <form role="search" method="get" action="/news" id="search" className="span-4 stack" style={{ gap: 8 }}>
              <label htmlFor="newsroom-search" className="small bold">{t(lang, "Search the newsroom", "Rechercher dans les actualités")}</label>
              <div style={{ position: "relative", height: 56 }}>
                {category && <input type="hidden" name="category" value={category} />}
                <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#4E5E53" strokeWidth="2" strokeLinecap="round" style={{ position: "absolute", left: 20, top: 18 }}><circle cx="11" cy="11" r="7" /><path d="M20 20l-4-4" /></svg>
                <input id="newsroom-search" name="q" type="search" defaultValue={q ?? ""} placeholder={t(lang, "Title, place or name", "Titre, lieu ou nom")} style={{ width: "100%", height: 56, appearance: "none", border: "1.5px solid var(--ink)", borderRadius: 999, padding: "0 116px 0 50px", background: "#fff", color: "var(--ink)", font: "inherit", fontSize: 16 }} />
                <button type="submit" className="btn btn--sm" style={{ position: "absolute", right: 6, top: 6 }}>{t(lang, "Search", "Rechercher")}</button>
              </div>
            </form>
            <div role="group" aria-label={t(lang, "Filter stories", "Filtrer les articles")} className="span-8 start-5 row" style={{ gap: 8, fontSize: 14 }}>
              <span className="sc muted" style={{ width: 96, flexShrink: 0, fontSize: 15 }}>{t(lang, "Topic", "Thème")}</span>
              <div className="chips">
                <Link className="chip" href={q ? `/news?q=${encodeURIComponent(q)}` : "/news"} aria-current={!category ? "true" : undefined}>{t(lang, "All", "Tout")}</Link>
                {categories.map((c) => (
                  <Link key={c.id} className="chip" href={`/news?category=${c.id}${q ? `&q=${encodeURIComponent(q)}` : ""}`} aria-current={String(c.id) === category ? "true" : undefined}>{tr(c, "name", lang)}</Link>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {lead ? (
        <section aria-label={t(lang, "Front page", "À la une")} style={{ padding: "0 0 104px" }}>
          <div className="wrap grid" style={{ paddingTop: 40, borderTop: "2px solid var(--ink)", alignItems: "start" }}>
            <article className="span-6 stack" style={{ gap: 0 }}>
              <div className="fig" style={{ height: 400 }}><img src={media(lead.medium_url || lead.image) || "/img/au-hq.jpg"} alt="" /></div>
              <p style={{ marginTop: 24 }}><Meta a={lead} lang={lang} /> <span className="small muted">· {lead.author}</span></p>
              <h2 className="h2 h2--md" style={{ marginTop: 12 }}><Link href={`/news/${lead.id}`}>{tr(lead, "title", lang)}</Link></h2>
              <p className="prose" style={{ marginTop: 16, color: "#33443A" }}>{excerpt(tr(lead, "content", lang), 40)}</p>
              <Link className="btn btn--md" href={`/news/${lead.id}`} style={{ alignSelf: "flex-start", marginTop: 26 }}>{t(lang, "Read the story", "Lire l’article")}</Link>
            </article>
            <div className="span-3 stack" style={{ gap: 0, paddingLeft: 24, borderLeft: "1px solid var(--line-2)" }}>
              {side.map((a, i) => (
                <article key={a.id} className="stack" style={{ gap: 8, marginTop: i ? 22 : 0, paddingTop: i ? 22 : 0, borderTop: i ? "1px solid var(--line-2)" : undefined }}>
                  {i === 0 && <div className="fig" style={{ height: 160, borderRadius: 16 }}><img src={media(a.medium_url || a.image) || "/img/karera-falls.jpg"} alt="" loading="lazy" /></div>}
                  <Meta a={a} lang={lang} />
                  <h3 className="h3 h3--sm" style={{ fontSize: 22 }}><Link href={`/news/${a.id}`}>{tr(a, "title", lang)}</Link></h3>
                  <p className="small muted" style={{ fontSize: 15 }}>{excerpt(tr(a, "content", lang), 28)}</p>
                  <span className="small muted" style={{ fontSize: 13 }}>{a.author}</span>
                </article>
              ))}
            </div>
            <aside aria-labelledby="in-brief" className="span-3 stack" style={{ gap: 0, paddingLeft: 24, borderLeft: "1px solid var(--line-2)" }}>
              <h2 id="in-brief" className="sc bold" style={{ fontSize: 17, paddingBottom: 12, borderBottom: "2px solid var(--ink)" }}>{t(lang, "In brief", "En bref")}</h2>
              <ol>
                {brief.map((a, i) => (
                  <li key={a.id}>
                    <Link href={`/news/${a.id}`} style={{ display: "grid", gridTemplateColumns: "30px minmax(0,1fr)", columnGap: 12, padding: "16px 0", borderBottom: "1px solid var(--line-2)" }}>
                      <span className="num" style={{ fontSize: 26, lineHeight: 1 }}>{i + 1}</span>
                      <span className="stack" style={{ gap: 4 }}>
                        <span className="sc" style={{ fontSize: 14, color: "var(--gold-ink)" }}>{a.category ? tr(a.category, "name", lang) : a.author} <span className="muted">· {fmtDate(a.publish_date, lang)}</span></span>
                        <span className="display" style={{ fontSize: 19, lineHeight: 1.2 }}>{tr(a, "title", lang)}</span>
                      </span>
                    </Link>
                  </li>
                ))}
              </ol>
              <Link className="more arrow" href={href(2)} style={{ marginTop: 12, minHeight: 44, display: "inline-flex", alignItems: "center" }}>{t(lang, "More news", "Plus d’actualités")}</Link>
            </aside>
          </div>
        </section>
      ) : news.results.length === 0 ? (
        <section className="sec"><div className="wrap"><Empty>{q ? t(lang, `No stories match “${q}”.`, `Aucun article ne correspond à « ${q} ».`) : t(lang, "No news published yet.", "Aucune actualité publiée pour le moment.")}</Empty></div></section>
      ) : null}

      {latest.length > 0 && (
        <section className="sec sec--ivory">
          <div className="wrap stack stack--lg">
            <div className="between">
              <div className="stack" style={{ gap: 6 }}>
                <span className="eyebrow">{cat ? tr(cat, "name", lang) : q ? t(lang, "Search results", "Résultats de recherche") : t(lang, "Ministry of Foreign Affairs · 2026", "Ministère des Affaires étrangères · 2026")}</span>
                <h2 className="h2">{q ? `“${q}”` : t(lang, "Latest", "Dernières nouvelles")}</h2>
              </div>
              <p className="muted" style={{ maxWidth: 420, textAlign: "right" }}>{t(lang, "News from the Ministry of Foreign Affairs, filed here and in the B4Africa app from one shared newsroom.", "Les nouvelles du Ministère des Affaires étrangères, publiées ici et dans l’app B4Africa depuis une même salle de presse.")}</p>
            </div>
            <div className="cols cols-3" style={{ gap: 24 }}>
              {latest.map((a) => <ArticleCard key={a.id} a={a} lang={lang} />)}
            </div>
            <nav className="pager" aria-label="Pagination" style={{ justifyContent: "center", gap: 20 }}>
              {news.previous && <Link className="btn btn--outline btn--md" href={href(pageNo - 1)}>← {t(lang, "Newer", "Plus récentes")}</Link>}
              <span className="small muted">{t(lang, `Page ${pageNo} of ${totalPages} · ${news.count} stories`, `Page ${pageNo} sur ${totalPages} · ${news.count} articles`)}</span>
              {news.next && <Link className="btn btn--outline btn--md" href={href(pageNo + 1)}>{t(lang, "Older stories", "Articles plus anciens")} →</Link>}
            </nav>
          </div>
        </section>
      )}

      {frontPage && dispatches.length > 0 && (
        <section className="sec">
          <div className="wrap grid" style={{ alignItems: "start" }}>
            <div className="span-5 stack" style={{ gap: 0 }}>
              <span className="eyebrow">{t(lang, "From the Mission in Addis Ababa", "Depuis la Mission à Addis-Abeba")}</span>
              <h2 className="h2" style={{ marginTop: 6 }}>{t(lang, "Embassy dispatches", "Dépêches de l’Ambassade")}</h2>
              <p className="lede lede--sm" style={{ marginTop: 14 }}>{t(lang, "The Embassy’s own reports from the African Union and its countries of accreditation. New dispatches are filed here and in the B4Africa app.", "Les comptes rendus de l’Ambassade depuis l’Union africaine et ses pays d’accréditation, publiés ici et dans l’app B4Africa.")}</p>
              <article className="stack" style={{ gap: 0, marginTop: 36 }}>
                <div className="fig" style={{ height: 380 }}><img src={media(dispatches[0].medium_url || dispatches[0].image) || "/img/ambassador.jpg"} alt="" loading="lazy" /></div>
                <p className="eyebrow" style={{ marginTop: 22, fontSize: 15 }}>{t(lang, "Embassy dispatch", "Dépêche de l’Ambassade")} · {fmtDate(dispatches[0].publish_date, lang)}</p>
                <h3 className="h3" style={{ marginTop: 10, fontSize: 29 }}><Link href={`/news/${dispatches[0].id}`}>{tr(dispatches[0], "title", lang)}</Link></h3>
                <p className="lede lede--sm" style={{ marginTop: 14, color: "#33443A" }}>{excerpt(tr(dispatches[0], "content", lang), 48)}</p>
                <Link className="btn btn--md" href={`/news/${dispatches[0].id}`} style={{ alignSelf: "flex-start", marginTop: 22 }}>{t(lang, "Read the dispatch", "Lire la dépêche")}</Link>
              </article>
            </div>
            <div className="span-7 start-6 stack" style={{ gap: 0, paddingLeft: 32, borderLeft: "1px solid var(--line-2)" }}>
              <div className="between" style={{ paddingBottom: 12, borderBottom: "2px solid var(--ink)", alignItems: "center" }}>
                <h3 className="sc bold" style={{ fontSize: 17 }}>{t(lang, "Earlier dispatches", "Dépêches précédentes")}</h3>
              </div>
              <ol>
                {dispatches.slice(1, 10).map((a) => (
                  <li key={a.id}>
                    <Link href={`/news/${a.id}`} style={{ display: "grid", gridTemplateColumns: "88px minmax(0,1fr) 24px", columnGap: 16, alignItems: "start", padding: "18px 0", borderBottom: "1px solid var(--line-2)" }}>
                      <time dateTime={a.publish_date} className="stack" style={{ gap: 0 }}>
                        <span className="display" style={{ fontSize: 22, lineHeight: 1.1 }}>{fmtDate(a.publish_date, lang, { year: undefined, month: "short" })}</span>
                        <span className="sc muted small">{new Date(a.publish_date).getFullYear()}</span>
                      </time>
                      <span className="stack" style={{ gap: 4 }}>
                        <span className="display" style={{ fontSize: 21, lineHeight: 1.2 }}>{tr(a, "title", lang)}</span>
                        <span className="small muted">{excerpt(tr(a, "content", lang), 20)}</span>
                      </span>
                      <span aria-hidden="true">→</span>
                    </Link>
                  </li>
                ))}
                {dispatches.length === 1 && <li className="muted small" style={{ padding: "18px 0" }}>{t(lang, "More dispatches will be filed here.", "D’autres dépêches seront publiées ici.")}</li>}
              </ol>
            </div>
          </div>
        </section>
      )}

      {frontPage && (
        <section className="sec sec--ivory" id="documents">
          <div className="wrap stack stack--lg">
            <SectionHead eyebrow={t(lang, "Official texts", "Textes officiels")} title={t(lang, "Communiqués, speeches and publications", "Communiqués, discours et publications")} more={t(lang, "All documents", "Tous les documents")} moreHref="/media#documents" />
            {documents.length ? (
              <ul className="rule-list rule-list--strong cols cols-2" style={{ gap: "0 32px" }}>
                {documents.slice(0, 8).map((d) => (
                  <li key={d.id}>
                    <a href={media(d.file)} target="_blank" rel="noopener">
                      <span className="stack" style={{ gap: 4 }}>
                        <span className="sc muted small">{t(lang, "Official document", "Document officiel")} · {fmtDate(d.created_at, lang)}</span>
                        <span className="display" style={{ fontSize: 20, lineHeight: 1.25 }}>{tr(d, "title", lang)}</span>
                      </span>
                      <span className="badge-pdf">{d.file_type.toUpperCase()} ↓ <span className="muted small">{d.file_size}</span></span>
                    </a>
                  </li>
                ))}
              </ul>
            ) : (
              <Empty>{t(lang, "Communiqués, speeches and publications will be published here as they are released.", "Les communiqués, discours et publications seront publiés ici au fur et à mesure.")}</Empty>
            )}
          </div>
        </section>
      )}

      {frontPage && (
        <section className="sec">
          <div className="wrap stack stack--lg">
            <SectionHead eyebrow={t(lang, "Media", "Médias")} title={t(lang, "Watch, read, browse", "Regarder, lire, parcourir")} more={t(lang, "Open the media library", "Ouvrir la médiathèque")} moreHref="/media" />
            <div className="grid" style={{ gap: 24 }}>
              <Link className="span-6 fig" href="/media#videos" style={{ height: 460 }}>
                <img src={media(video?.medium_url || video?.thumbnail) || "/img/drummers.jpg"} alt="" loading="lazy" style={{ objectPosition: "45% 40%" }} />
                <span className="scrim" style={{ background: "rgba(15,42,27,0.22)" }} /><PlayIcon />
                <span className="panel between" style={{ position: "absolute", left: 20, right: 20, bottom: 20, borderRadius: 18, padding: "20px 22px", alignItems: "center", flexWrap: "nowrap" }}>
                  <span className="stack" style={{ gap: 4 }}>
                    <span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "Videos", "Vidéos")}</span>
                    <span className="h3">{video ? tr(video, "title", lang) : t(lang, "Summit coverage and films on Burundi", "Couverture des sommets et films sur le Burundi")}</span>
                    <span className="small muted">{t(lang, "The B4Africa app notifies you when a session goes live.", "L’app B4Africa vous prévient quand une session passe en direct.")}</span>
                  </span>
                  <span aria-hidden="true" className="icon-btn" style={{ borderColor: "var(--ink)", borderWidth: 1.5, flexShrink: 0 }}>→</span>
                </span>
              </Link>
              <Link className="span-3 fig" href="/media#magazine" style={{ height: 460 }}>
                <img src={media(magazine?.medium_url || magazine?.cover_image) || "/img/dancers.jpg"} alt="" loading="lazy" style={{ objectPosition: "60% center" }} />
                <span className="panel" style={{ position: "absolute", left: 16, right: 16, bottom: 16, padding: "18px 20px", gap: 4 }}>
                  <span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "Digital magazine", "Magazine numérique")}</span>
                  <span className="h3 h3--sm">{magazine ? tr(magazine, "title", lang) : t(lang, "The B4Africa magazine", "Le magazine B4Africa")}</span>
                  <span className="small muted">{t(lang, "Read online, or save editions offline in the app.", "À lire en ligne, ou hors ligne dans l’app.")}</span>
                </span>
              </Link>
              <Link className="span-3 fig" href="/media#albums" style={{ height: 460 }}>
                <img src={media(album?.cover_image) || "/img/lake-tanganyika.jpg"} alt="" loading="lazy" style={{ objectPosition: "22% center" }} />
                <span className="panel" style={{ position: "absolute", left: 16, right: 16, bottom: 16, padding: "18px 20px", gap: 4 }}>
                  <span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "Photo galleries", "Galeries photo")}</span>
                  <span className="h3 h3--sm">{album ? tr(album, "title", lang) : t(lang, "Burundi and the Embassy, album by album", "Le Burundi et l’Ambassade, album par album")}</span>
                </span>
              </Link>
            </div>
          </div>
        </section>
      )}

      {chairship.length > 0 && (
        <section className="sec sec--ivory" aria-labelledby="chairship-title">
          <div className="wrap stack stack--lg">
            <div className="between">
              <div className="stack" style={{ gap: 6 }}>
                <span className="eyebrow">{t(lang, "From the chairmanship newsroom", "Depuis la salle de presse de la présidence")}</span>
                <h2 id="chairship-title" className="h2">{t(lang, "Also on burundichairship.africa", "Aussi sur burundichairship.africa")}</h2>
              </div>
              <a className="more arrow" href="https://burundichairship.africa" target="_blank" rel="noopener">{t(lang, "Visit the chairmanship site", "Visiter le site de la présidence")}</a>
            </div>
            <div className="cols cols-3" style={{ gap: 24 }}>
              {chairship.map((p) => (
                <a key={p.id} className="card card--flush" href={p.link} target="_blank" rel="noopener">
                  {p.image ? <img src={p.image} alt="" loading="lazy" style={{ width: "100%", aspectRatio: "16 / 10", objectFit: "cover" }} /> : <div style={{ aspectRatio: "16 / 10", background: "var(--paper)" }} />}
                  <div className="card-body" style={{ padding: "22px 24px 26px" }}>
                    <span className="meta">{p.categories[0] ? `${p.categories[0]} · ` : ""}{fmtDate(p.date, lang)}</span>
                    <h3 className="h3 h3--sm">{p.title}</h3>
                    {p.excerpt && <p className="small muted">{excerpt(p.excerpt, 26)}</p>}
                    <span className="small bold">burundichairship.africa ↗</span>
                  </div>
                </a>
              ))}
            </div>
          </div>
        </section>
      )}
      <section className="sec sec--dark">
        <div className="wrap grid" style={{ alignItems: "start" }}>
          <div className="span-5 stack" style={{ gap: 0 }}>
            <span className="eyebrow eyebrow--gold">{t(lang, "Press & follow", "Presse & réseaux")}</span>
            <h2 className="h2" style={{ marginTop: 8 }}>{t(lang, "Media enquiries", "Demandes des médias")}</h2>
            <p style={{ marginTop: 16, fontSize: 17, lineHeight: 1.7, color: "var(--mint-2)" }}>{t(lang, "Journalists and editors covering Burundi’s AU Chairmanship or the Embassy’s work can write to or call the Embassy in Addis Ababa.", "Les journalistes et rédactions qui couvrent la Présidence burundaise de l’UA ou le travail de l’Ambassade peuvent écrire ou appeler l’Ambassade à Addis-Abeba.")}</p>
            <dl className="dl" style={{ marginTop: 32, fontSize: 17 }}>
              <dt style={{ color: "#A7BFA9" }}>Email</dt><dd><a href="mailto:info@burundiaddis.gov.bi" className="bold" style={{ color: "#fff" }}>info@burundiaddis.gov.bi</a></dd>
              <dt style={{ color: "#A7BFA9" }}>{t(lang, "Phone", "Téléphone")}</dt><dd>+251 114 651 300<br />+251 114 655 547<br />+251 911 208 857</dd>
              <dt style={{ color: "#A7BFA9" }}>{t(lang, "Hours", "Horaires")}</dt><dd>{t(lang, "Monday to Friday, 7:00–16:00", "Lundi à vendredi, 7h00–16h00")}</dd>
              <dt style={{ color: "#A7BFA9" }}>{t(lang, "Address", "Adresse")}</dt><dd>Bole Sub-City, Kebele 03/05, Addis Ababa</dd>
            </dl>
          </div>
          <div className="span-6 start-7 stack" style={{ gap: 0 }}>
            <span className="eyebrow eyebrow--gold">{t(lang, "Follow the Embassy", "Suivre l’Ambassade")}</span>
            <div className="stack" style={{ gap: 10, marginTop: 14 }}>
              <a className="btn btn--gold btn--md" href="https://x.com/BurundinAddis" rel="noopener" style={{ alignSelf: "flex-start" }}>@BurundinAddis {t(lang, "on X", "sur X")}</a>
              <div className="chips">
                {["Burundi4Africa", "water4africa", "ARise"].map((h) => <a key={h} className="btn btn--ghost btn--sm" href={`https://x.com/hashtag/${h}`} rel="noopener">#{h}</a>)}
              </div>
            </div>
            <div className="row" style={{ gap: 22, marginTop: 28, paddingTop: 28, borderTop: "1px solid rgba(255,255,255,0.18)" }}>
              <img src="/img/b4africa-white.png" alt="B4Africa" width={132} height={44} style={{ width: 132, height: "auto" }} />
              <p className="display" style={{ flex: 1, fontSize: 22, lineHeight: 1.25, minWidth: 200 }}>{t(lang, "Breaking news alerts come first in the B4Africa app.", "Les alertes d’actualité arrivent d’abord dans l’app B4Africa.")}</p>
              <a className="btn btn--ghost btn--md" href="/app">{t(lang, "Get the app", "Télécharger l’app")}</a>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
