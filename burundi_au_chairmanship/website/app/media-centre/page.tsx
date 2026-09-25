import type { Metadata } from "next";
import Link from "next/link";
import { api, media } from "@/lib/api";
import { fmtDate, getLang, t, tr } from "@/lib/i18n";
import type { Resource } from "@/lib/types";
import { VIDEO_CATEGORIES, categoryLabel } from "./videos";
import { Crumbs, Empty, SectionHead } from "@/components/ui";
import s from "./media.module.css";

export const metadata: Metadata = {
  title: "Media centre",
  description: "Videos, the B4Africa digital magazine, photo albums and official documents from the Embassy and Burundi’s AU Chairmanship.",
};

const RESOURCE_CATEGORIES: Array<[Resource["category"], string, string]> = [
  ["official_documents", "Official documents", "Documents officiels"],
  ["country_info", "Country information", "Informations sur le pays"],
  ["media", "Media resources", "Ressources médias"],
  ["reference", "Reference guides", "Guides de référence"],
];

const Play = ({ size = 22 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="#0F2A1B" aria-hidden="true"><path d="M8 5.5v13l11-6.5z" /></svg>
);

export default async function MediaPage({ searchParams }: { searchParams: Promise<{ category?: string; doc?: string }> }) {
  const lang = await getLang();
  const { category, doc } = await searchParams;
  const [live, videos, magazines, albums, resources, social] = await Promise.all([
    api.live(), api.videos({ page_size: 100 }), api.magazines(), api.albums(), api.resources(), api.social(),
  ]);

  const liveNow = live.results.find((l) => l.status === "live") ?? null;
  const sortedVideos = [...videos.results].sort((a, b) => b.publish_date.localeCompare(a.publish_date));
  const hero = sortedVideos.find((v) => v.is_featured) ?? sortedVideos[0] ?? null;
  const upNext = sortedVideos.filter((v) => v.id !== hero?.id).slice(0, 3);
  const nextLive = live.results.find((l) => l.status === "upcoming") ?? null;
  const shown = category ? sortedVideos.filter((v) => v.category === category) : sortedVideos;

  const mags = [...magazines.results].sort((a, b) => b.publish_date.localeCompare(a.publish_date));
  const [latestMag, ...pastMags] = mags;

  const albs = [...albums.results].sort((a, b) => Number(b.is_featured) - Number(a.is_featured) || b.created_at.localeCompare(a.created_at));
  const [leadAlbum, ...otherAlbums] = albs;

  const docs = doc ? resources.results.filter((r) => r.category === doc) : resources.results;
  const resourceLabel = (c: Resource["category"]) => {
    const row = RESOURCE_CATEGORIES.find(([k]) => k === c);
    return row ? t(lang, row[1], row[2]) : c;
  };

  return (
    <>
      {/* hero: the player */}
      <section className="sec--dark" style={{ padding: "64px 0 96px" }}>
        <div className="wrap stack stack--lg">
          <div className="grid" style={{ alignItems: "end" }}>
            <div className="span-7 stack" style={{ gap: 20 }}>
              <div style={{ color: "var(--mint-2)" }}><Crumbs lang={lang} items={[[t(lang, "Newsroom", "Actualités"), "/news"], [t(lang, "Media centre", "Médiathèque")]]} /></div>
              <h1 className="h1" style={{ fontSize: "clamp(40px, 5vw, 76px)" }}>
                {lang === "fr" ? <>Regarder, lire et <em className="hl">revoir</em></> : <>Watch, read and <em className="hl">look back</em></>}
              </h1>
            </div>
            <p className="span-4 start-9" style={{ fontSize: 18, lineHeight: 1.7, color: "var(--mint-2)" }}>
              {t(lang,
                "Videos, the B4Africa digital magazine, photo albums and official documents from the Embassy and Burundi’s AU Chairmanship. The same library is in the B4Africa app.",
                "Vidéos, le magazine numérique B4Africa, albums photo et documents officiels de l’Ambassade et de la Présidence burundaise de l’UA. La même bibliothèque est dans l’app B4Africa.")}
            </p>
          </div>

          <div className="grid" style={{ alignItems: "start" }}>
            <figure className="span-8">
              {liveNow ? (
                <a className={s.player} href={liveNow.stream_url} rel="noopener">
                  <img src={media(liveNow.thumbnail) || "/img/drummers.jpg"} alt="" />
                  <span className="scrim" />
                  <span className="tag tag--live" style={{ position: "absolute", left: 24, top: 24 }}>LIVE</span>
                  <span className="play"><Play size={38} /></span>
                </a>
              ) : hero ? (
                <Link className={s.player} href={`/media-centre/videos/${hero.id}`}>
                  <img src={media(hero.medium_url || hero.thumbnail) || "/img/drummers.jpg"} alt="" />
                  <span className="scrim" />
                  <span className="tag tag--gold" style={{ position: "absolute", left: 24, top: 24 }}>{t(lang, "LATEST", "DERNIÈRE")}</span>
                  <span className="play"><Play size={38} /></span>
                  {hero.duration && <span className={s.dur} style={{ right: 24, bottom: 22, fontSize: 13 }}>{hero.duration}</span>}
                </Link>
              ) : (
                <Empty>{t(lang, "No videos published yet.", "Aucune vidéo publiée pour le moment.")}</Empty>
              )}
              {(liveNow || hero) && (
                <figcaption className={s.playerCap}>
                  <span className="stack" style={{ gap: 6 }}>
                    <span className="sc" style={{ fontSize: 15, color: "var(--gold)" }}>
                      {liveNow ? t(lang, "Live now", "En direct") : `${categoryLabel(hero!.category, lang)} · ${fmtDate(hero!.publish_date, lang)}`}
                    </span>
                    <span className="h3 h3--lg" style={{ color: "#fff" }}>{tr(liveNow ?? hero, "title", lang)}</span>
                  </span>
                  <span className={s.playerNote}><span className="dot dot--red" style={{ marginTop: 7, width: 10, height: 10 }} />{t(lang, "Live sessions stream here and in the B4Africa app when on air", "Les sessions en direct sont diffusées ici et dans l’app B4Africa")}</span>
                </figcaption>
              )}
            </figure>
            <aside className="span-4 stack" style={{ gap: 14 }}>
              <span className="eyebrow eyebrow--gold">{t(lang, "Up next", "À suivre")}</span>
              <ol className={s.upnext}>
                {upNext.map((v) => (
                  <li key={v.id}>
                    <Link href={`/media-centre/videos/${v.id}`}>
                      <span className={s.thumb}>
                        <img src={media(v.medium_url || v.thumbnail) || "/img/karera-falls.jpg"} alt="" loading="lazy" />
                        {v.duration && <span className={s.dur}>{v.duration}</span>}
                      </span>
                      <span className="stack" style={{ gap: 4 }}>
                        <span className="sc" style={{ fontSize: 14, color: "var(--mint-2)" }}>{categoryLabel(v.category, lang)} · {fmtDate(v.publish_date, lang, { year: undefined })}</span>
                        <span style={{ fontFamily: "var(--display)", fontSize: 20, lineHeight: 1.25, color: "#fff" }}>{tr(v, "title", lang)}</span>
                      </span>
                    </Link>
                  </li>
                ))}
              </ol>
              {nextLive && (
                <div className={s.liveBox}>
                  <span className="row" style={{ gap: 10, fontSize: 15, color: "var(--mint-2)" }}><span className="tag tag--live" style={{ fontSize: 11 }}>LIVE</span>{tr(nextLive, "title", lang)}{nextLive.scheduled_time ? ` · ${fmtDate(nextLive.scheduled_time, lang, { hour: "2-digit", minute: "2-digit" })}` : ""}</span>
                  <a href="/app" className="bold arrow" style={{ color: "#fff" }}>{t(lang, "Set a reminder in the B4Africa app", "Programmer un rappel dans l’app B4Africa")}</a>
                </div>
              )}
            </aside>
          </div>
        </div>
      </section>

      {/* video library */}
      <section className="sec" id="videos">
        <div className="wrap">
          <SectionHead eyebrow={t(lang, "Video library", "Vidéothèque")} title={t(lang, "Speeches, sessions and stories", "Discours, sessions et récits")} more={t(lang, "Watch in the B4Africa app", "Regarder dans l’app B4Africa")} moreHref="/app" />
          <div className="chips" role="group" aria-label={t(lang, "Filter videos", "Filtrer les vidéos")} style={{ marginTop: 28 }}>
            <Link className="chip" href="/media-centre#videos" aria-current={!category ? "true" : undefined}>{t(lang, "All videos", "Toutes les vidéos")}</Link>
            {VIDEO_CATEGORIES.map(([k, en, fr]) => (
              <Link key={k} className="chip" href={`/media-centre?category=${k}#videos`} aria-current={category === k ? "true" : undefined}>{t(lang, en, fr)}</Link>
            ))}
          </div>
          {shown.length ? (
            <div className={s.videos} style={{ marginTop: 36 }}>
              {shown.map((v) => (
                <Link key={v.id} className={`${s.video} no-ul`} href={`/media-centre/videos/${v.id}`}>
                  <span className={s.still}>
                    <img src={media(v.medium_url || v.thumbnail) || "/img/president-podium.jpg"} alt="" loading="lazy" />
                    <span className={s.smallPlay}><Play /></span>
                    {v.duration && <span className={s.dur} style={{ right: 12, bottom: 12 }}>{v.duration}</span>}
                  </span>
                  <span className="stack" style={{ gap: 6 }}>
                    <span className="num small">{categoryLabel(v.category, lang)}</span>
                    <span className="h3 h3--sm">{tr(v, "title", lang)}</span>
                    <span className="small muted">{fmtDate(v.publish_date, lang)}</span>
                  </span>
                </Link>
              ))}
            </div>
          ) : (
            <div style={{ marginTop: 36 }}><Empty>{t(lang, "No videos in this category yet.", "Aucune vidéo dans cette catégorie pour le moment.")}</Empty></div>
          )}
        </div>
      </section>

      {/* digital magazine */}
      <section className="sec sec--ivory" id="magazine">
        <div className="wrap grid grid--center">
          <div className="span-5">
            {latestMag ? (
              <div className={s.cover}>
                <span aria-hidden="true" className={s.coverShadow} />
                <a className={s.coverLink} href={media(latestMag.effective_pdf_url) || undefined} aria-label={t(lang, "Read the latest issue of the B4Africa magazine", "Lire le dernier numéro du magazine B4Africa")} rel="noopener">
                  <img src={media(latestMag.medium_url || latestMag.cover_image)} alt={tr(latestMag, "title", lang)} loading="lazy" />
                  {latestMag.is_featured && <span className={s.newIssue}>{lang === "fr" ? <>NOUVEAU<br />NUMÉRO</> : <>NEW<br />ISSUE</>}</span>}
                </a>
              </div>
            ) : (
              <Empty>{t(lang, "The first issue of the magazine will appear here.", "Le premier numéro du magazine paraîtra ici.")}</Empty>
            )}
          </div>
          <div className="span-6 start-7 stack" style={{ gap: 0 }}>
            <span className="eyebrow">{t(lang, "Digital magazine", "Magazine numérique")}</span>
            <h2 className="h2" style={{ marginTop: 14 }}>{t(lang, "The B4Africa magazine", "Le magazine B4Africa")}</h2>
            <p className="lede lede--sm" style={{ marginTop: 18 }}>
              {t(lang,
                "Read the latest publications and featured articles from Burundi’s AU Chairmanship year, in English and French. Download an issue in the B4Africa app and it stays on your phone to read offline.",
                "Lisez les dernières publications et articles à la une de l’année de Présidence burundaise de l’UA, en anglais et en français. Téléchargez un numéro dans l’app B4Africa : il reste sur votre téléphone, hors ligne.")}
            </p>
            {latestMag && (
              <div className="row" style={{ marginTop: 28 }}>
                {latestMag.effective_pdf_url && <a className="btn btn--md" href={media(latestMag.effective_pdf_url)} rel="noopener">{t(lang, "Read now", "Lire maintenant")}</a>}
                <span className="small muted">{tr(latestMag, "title", lang)} · {fmtDate(latestMag.publish_date, lang, { day: undefined })}{latestMag.page_count ? ` · ${latestMag.page_count} ${t(lang, "pages", "pages")}` : ""}{latestMag.file_size ? ` · ${latestMag.file_size}` : ""}</span>
              </div>
            )}
            {pastMags.length > 0 && (
              <div className="stack" style={{ gap: 14, marginTop: 40, paddingTop: 16, borderTop: "2px solid var(--ink)" }}>
                <span className="eyebrow">{t(lang, "Past issues", "Numéros précédents")}</span>
                <div className={s.issues}>
                  {pastMags.map((m) => (
                    <a key={m.id} className={`${s.issue} no-ul`} href={media(m.effective_pdf_url) || undefined} rel="noopener">
                      <img src={media(m.medium_url || m.cover_image)} alt={tr(m, "title", lang)} loading="lazy" />
                      <span className="small"><b>{tr(m, "title", lang)}</b><br /><span className="muted">{fmtDate(m.publish_date, lang, { day: undefined })}</span></span>
                    </a>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </section>

      {/* photo galleries */}
      <section className="sec" id="albums">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "Photo galleries", "Galeries photo")} title={t(lang, "Albums", "Albums")} />
          {leadAlbum ? (
            <div className="grid" style={{ alignItems: "start" }}>
              <Link className="span-7 stack no-ul" style={{ gap: 18 }} href={`/media-centre/albums/${leadAlbum.id}`}>
                <span className={s.albumLead}>
                  {[leadAlbum.cover_image, ...leadAlbum.photos.map((p) => p.medium_url || p.image)].slice(0, 4).map((src, i) => (
                    <span key={i} className={`fig ${i === 0 ? "" : ""}`}><img src={media(src)} alt="" loading="lazy" /></span>
                  ))}
                </span>
                <span className="between" style={{ alignItems: "flex-start" }}>
                  <span className="stack" style={{ gap: 6 }}>
                    <span className="h3 h3--lg" style={{ fontSize: 32 }}>{tr(leadAlbum, "title", lang)}</span>
                    {tr(leadAlbum, "description", lang) && <span className="muted" style={{ fontSize: 15 }}>{tr(leadAlbum, "description", lang)}</span>}
                  </span>
                  <span className={s.count}>{leadAlbum.photo_count} {t(lang, "photos", "photos")}</span>
                </span>
              </Link>
              <div className="span-5 start-8 stack">
                {otherAlbums.slice(0, 2).map((a) => (
                  <Link key={a.id} className="stack no-ul" style={{ gap: 14 }} href={`/media-centre/albums/${a.id}`}>
                    <span className={s.albumSmall}>
                      {[a.cover_image, ...a.photos.map((p) => p.medium_url || p.image)].slice(0, 3).map((src, i) => (
                        <span key={i} className="fig"><img src={media(src)} alt="" loading="lazy" /></span>
                      ))}
                    </span>
                    <span className="between" style={{ alignItems: "flex-end" }}>
                      <span className="stack" style={{ gap: 4 }}><span className="h3 h3--sm" style={{ fontSize: 26 }}>{tr(a, "title", lang)}</span>{tr(a, "description", lang) && <span className="small muted">{tr(a, "description", lang)}</span>}</span>
                      <span className={s.count}>{a.photo_count} {t(lang, "photos", "photos")}</span>
                    </span>
                  </Link>
                ))}
              </div>
              {otherAlbums.length > 2 && (
                <div className="span-12 chips">
                  {otherAlbums.slice(2).map((a) => <Link key={a.id} className="chip" href={`/media-centre/albums/${a.id}`}>{tr(a, "title", lang)} · {a.photo_count}</Link>)}
                </div>
              )}
            </div>
          ) : (
            <Empty>{t(lang, "No albums published yet.", "Aucun album publié pour le moment.")}</Empty>
          )}
        </div>
      </section>

      {/* publications and documents */}
      <section className="sec sec--ivory" id="documents">
        <div className="wrap">
          <div className="between">
            <div className="stack" style={{ gap: 6 }}>
              <span className="eyebrow">{t(lang, "Publications & documents", "Publications & documents")}</span>
              <h2 className="h2">{t(lang, "Documents", "Documents")}</h2>
            </div>
            <div className="chips" role="group" aria-label={t(lang, "Filter documents by category", "Filtrer les documents par catégorie")}>
              <Link className="chip" href="/media-centre#documents" aria-current={!doc ? "true" : undefined}>{t(lang, "All", "Tous")}</Link>
              {RESOURCE_CATEGORIES.map(([k, en, fr]) => (
                <Link key={k} className="chip" href={`/media-centre?doc=${k}#documents`} aria-current={doc === k ? "true" : undefined}>{t(lang, en, fr)}</Link>
              ))}
            </div>
          </div>
          {docs.length ? (
            <table className={s.docTable}>
              <thead>
                <tr>
                  <th>{t(lang, "Document", "Document")}</th>
                  <th>{t(lang, "Category", "Catégorie")}</th>
                  <th>{t(lang, "Type", "Type")}</th>
                  <th>{t(lang, "Download", "Télécharger")}</th>
                </tr>
              </thead>
              <tbody>
                {docs.map((r) => (
                  <tr key={r.id}>
                    <td>{tr(r, "title", lang)}</td>
                    <td className="muted">{resourceLabel(r.category)}</td>
                    <td style={{ textTransform: "uppercase" }}>{r.file_type}</td>
                    <td><a className="badge-pdf" href={media(r.file)} rel="noopener">{r.file_size ? `${r.file_size} ↓` : "↓"}</a></td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <div style={{ marginTop: 32 }}><Empty>{t(lang, "Documents will be listed here as they are published.", "Les documents seront listés ici au fur et à mesure de leur publication.")}</Empty></div>
          )}
        </div>
      </section>

      {/* follow */}
      <section className="sec--dark" style={{ padding: "88px 0" }}>
        <div className="wrap grid" style={{ alignItems: "start" }}>
          <div className="span-5 stack" style={{ gap: 16 }}>
            <span className="eyebrow eyebrow--gold">{t(lang, "Follow us", "Suivez-nous")}</span>
            <h2 className="h2">{t(lang, "Stay connected with the chairmanship", "Restez connectés à la présidence")}</h2>
          </div>
          <div className="span-6 start-7 stack" style={{ gap: 28 }}>
            {social.length ? (
              <ul className={s.social}>
                {social.map((so) => (
                  <li key={so.id}>
                    <a href={so.url} rel="noopener">
                      <span className={s.socialIcon} aria-hidden="true">{so.platform === "twitter" ? "X" : so.platform.slice(0, 2)}</span>
                      <span className="stack" style={{ gap: 2 }}>
                        <span style={{ fontFamily: "var(--display)", fontSize: 22, color: "#fff" }}>{lang === "fr" && so.display_name_fr ? so.display_name_fr : so.display_name}</span>
                        <span className="small" style={{ color: "var(--mint-2)" }}>{so.handle}{so.follower_count ? ` · ${so.follower_count}` : ""}</span>
                      </span>
                      <span aria-hidden="true">→</span>
                    </a>
                  </li>
                ))}
              </ul>
            ) : (
              <Empty>{t(lang, "Social links will appear here.", "Les liens sociaux apparaîtront ici.")}</Empty>
            )}
            <div className="chips">
              <span className="chip" style={{ background: "var(--gold)", borderColor: "var(--gold)" }}>#Burundi4Africa</span>
              <span className="chip" style={{ background: "transparent", color: "#fff", borderColor: "rgba(234,242,227,0.45)" }}>#water4africa</span>
              <span className="chip" style={{ background: "transparent", color: "#fff", borderColor: "rgba(234,242,227,0.45)" }}>#ARise</span>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
