import type { Metadata } from "next";
import Link from "next/link";
import { api, media } from "@/lib/api";
import { fmtDate, getLang, t, tr } from "@/lib/i18n";
import { Crumbs, Ico, ICONS, PlayIcon, SectionHead } from "@/components/ui";

export const metadata: Metadata = {
  title: "AU Chairmanship 2026",
  description: "Burundi chairs the African Union in 2026: the theme of the year, the three priorities, summit coverage, speeches and documents.",
};

const FALLBACK_THEME = "Assuring Sustainable Water Availability and Safe Sanitation Systems to Achieve the Goals of Agenda 2063";
const ICON_BY_INDEX = [ICONS.drop, ICONS.rise, ICONS.shield];
const MOSAIC_FALLBACK = [
  ["/img/gavel-handover.jpg", "Handover of the chairmanship · 39th Summit"],
  ["/img/president-youth.jpg", "5th Continental Dialogue"],
  ["/img/dancers.jpg", "Welcome dance"],
  ["/img/diplomats-flags.jpg", ""],
];
const MOSAIC_CELLS = [
  { gridColumn: "span 7", gridRow: "span 2" },
  { gridColumn: "span 5" },
  { gridColumn: "span 3" },
  { gridColumn: "span 2" },
];

export default async function ChairmanshipPage() {
  const lang = await getLang();
  const [agendas, albums, live, videos, resources, magazines, settings] = await Promise.all([
    api.agendas(), api.albums(), api.live(), api.videos({ page_size: 1 }), api.resources(), api.magazines(), api.settings(),
  ]);
  const theme = settings && settings.summit_theme.length > 3 ? tr(settings, "summit_theme", lang) : FALLBACK_THEME;
  const liveNow = live.results.find((l) => l.status === "live");
  const video = videos.results[0];
  const watch = liveNow
    ? { href: liveNow.stream_url, img: media(liveNow.thumbnail), title: tr(liveNow, "title", lang), live: true }
    : video
      ? { href: "/media-centre", img: media(video.medium_url || video.thumbnail_url || video.thumbnail), title: tr(video, "title", lang), live: false }
      : null;
  const docs = resources.results.filter((r) => r.category === "official_documents").slice(0, 3);
  const magazine = magazines.results[0];
  const tiles = MOSAIC_FALLBACK.map(([src, cap], i) => {
    const a = albums.results[i];
    return a ? { src: media(a.photos[0]?.medium_url || a.cover_image) || src, cap: tr(a, "title", lang), href: `/media-centre#album-${a.id}` } : { src, cap, href: "/media-centre" };
  });

  return (
    <>
      <section className="page-hero">
        <div className="wrap grid grid--center">
          <div className="span-6 stack" style={{ gap: 24 }}>
            <Crumbs lang={lang} items={[[t(lang, "AU Chairmanship 2026", "Présidence de l’UA 2026")]]} />
            <span className="pill"><span className="dot" />{t(lang, "African Union · 2026", "Union africaine · 2026")}</span>
            <h1 className="h1">{lang === "fr" ? <>Le <em className="hl">cœur de l’Afrique</em> préside son Union</> : <>The <em className="hl">heart of Africa</em> chairs its Union</>}</h1>
            <p className="lede">{t(lang, "President Évariste Ndayishimiye was elected Chairperson of the African Union at the 39th Summit in Addis Ababa, in February 2026. The Embassy, as Burundi’s Permanent Mission to the AU, supports the chairmanship through the year.", "Le Président Évariste Ndayishimiye a été élu Président de l’Union africaine lors du 39e Sommet à Addis-Abeba, en février 2026. L’Ambassade, Mission permanente du Burundi auprès de l’UA, accompagne la présidence tout au long de l’année.")}</p>
            <div className="row btn-row"><a className="btn" href="#priorities">{t(lang, "The three priorities", "Les trois priorités")}</a><a className="btn btn--outline" href="#watch">{t(lang, "Watch and follow", "Regarder et suivre")}</a></div>
          </div>
          <div className="span-5 start-8" style={{ position: "relative", minHeight: 520 }}>
            <div className="fig" style={{ position: "absolute", right: 0, top: 0, width: "80%", aspectRatio: "440 / 520" }}><img src="/img/president-podium.jpg" alt="President Évariste Ndayishimiye at the African Union podium" /></div>
            <div className="fig" style={{ position: "absolute", left: 0, bottom: 0, width: "56%", aspectRatio: "280 / 200", border: "6px solid #fff", borderRadius: 18 }}><img src="/img/chair-seat.jpg" alt="The Chairperson’s seat at the African Union, with the Burundi and AU flags" /></div>
          </div>
        </div>
      </section>

      <section className="sec sec--dark" style={{ padding: "88px 0" }}>
        <div className="wrap grid" style={{ alignItems: "end" }}>
          <div className="span-9 stack" style={{ gap: 18 }}>
            <span className="eyebrow eyebrow--gold">{t(lang, "AU theme of the year 2026", "Thème de l’année 2026 de l’UA")}</span>
            <blockquote className="quote" style={{ fontSize: "clamp(28px, 3.2vw, 46px)" }}>“{theme}”</blockquote>
          </div>
          <a className="span-3 btn btn--gold btn--md" style={{ justifySelf: "end" }} href="https://au.int/en/theme/2026" rel="noopener">{t(lang, "Read the AU theme ↗", "Lire le thème de l’UA ↗")}</a>
        </div>
      </section>

      <section id="priorities" className="sec">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "The chairmanship’s agenda", "L’agenda de la présidence")} title={t(lang, "Three priorities for the year", "Trois priorités pour l’année")} />
          <div className="cols cols-3">
            {agendas.map((a, i) => (
              <Link key={a.id} className="card" style={{ padding: 32, minHeight: 360, borderRadius: 22 }} href={`/au-2026/priorities#${a.slug}`}>
                <div className="between" style={{ alignItems: "center" }}><span className="num" style={{ fontSize: 36 }}>{String(i + 1).padStart(2, "0")}</span><span className="icon-circle icon-circle--lg"><Ico d={ICON_BY_INDEX[i % 3]} size={26} /></span></div>
                <h3 className="h3 h3--lg">{tr(a, "title", lang)}</h3>
                <p className="muted">{tr(a, "description", lang)}</p>
                <span className="push bold arrow">{t(lang, "Objectives and current initiatives", "Objectifs et initiatives en cours")}</span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "Gallery", "Galerie")} title={t(lang, "The year in pictures", "L’année en images")} more={t(lang, "All albums", "Tous les albums")} moreHref="/media-centre#albums" />
          <div className="mosaic">
            {tiles.map((tile, i) => (
              <Link key={i} className="fig" style={MOSAIC_CELLS[i]} href={tile.href}>
                <img src={tile.src} alt="" loading="lazy" style={{ objectPosition: "center 30%" }} />
                {tile.cap && <span className="cap-pill">{tile.cap}</span>}
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section id="watch" className="sec">
        <div className="wrap grid grid--center">
          {watch && (
            <a className="span-7 fig fig--16x9" href={watch.href} rel="noopener">
              <img src={watch.img || "/img/drummers.jpg"} alt="" loading="lazy" style={{ objectPosition: "40% center" }} />
              <span className="scrim" /><PlayIcon />
              {watch.live && <span className="tag tag--live" style={{ position: "absolute", left: 20, top: 20 }}>LIVE</span>}
              <span style={{ position: "absolute", left: 20, right: 20, bottom: 20, color: "#fff", fontFamily: "var(--display)", fontSize: 26 }}>{watch.title}</span>
            </a>
          )}
          <div className={`${watch ? "span-5" : "span-12"} stack`} style={{ gap: 18 }}>
            <span className="eyebrow">{t(lang, "Watch and follow", "Regarder et suivre")}</span>
            <h2 className="h2">{t(lang, "Summit coverage, live and on demand", "La couverture des sommets, en direct et à la demande")}</h2>
            <p className="lede lede--sm">{t(lang, "Sessions, speeches and interviews, with chapters and subtitles in English and French. Get notified in the B4Africa app when a session goes live.", "Sessions, discours et entretiens, avec chapitres et sous-titres en anglais et en français. Soyez notifié dans l’app B4Africa quand une session passe en direct.")}</p>
            <div className="row" style={{ gap: 16 }}>
              <img src="/img/b4africa.png" alt="B4Africa" width={150} height={50} style={{ width: 150, height: "auto" }} />
              <Link className="btn btn--md" href="/media-centre">{t(lang, "Media centre", "Médiathèque")}</Link>
            </div>
          </div>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap grid">
          <div className="span-4 stack" style={{ gap: 6 }}>
            <span className="eyebrow">{t(lang, "Speeches & documents", "Discours et documents")}</span>
            <h2 className="h2">{t(lang, "On the record", "Textes officiels")}</h2>
          </div>
          <ul className="span-7 start-6 rule-list rule-list--strong">
            {docs.map((d) => (
              <li key={d.id}><a href={media(d.file)} rel="noopener">
                <span className="stack" style={{ gap: 4 }}><span className="meta">{d.file_type.toUpperCase()} · {fmtDate(d.created_at, lang)}</span><span className="h3 h3--sm">{tr(d, "title", lang)}</span></span>
                <span className="badge-pdf">{d.file_size} ↓</span>
              </a></li>
            ))}
            {magazine && (
              <li><a href={media(magazine.effective_pdf_url) || "/media-centre#magazine"} rel="noopener">
                <span className="stack" style={{ gap: 4 }}><span className="meta">Magazine · {fmtDate(magazine.publish_date, lang, { day: undefined })}</span><span className="h3 h3--sm">{tr(magazine, "title", lang)}</span></span>
                <span className="badge-pdf">{t(lang, "Read", "Lire")} →</span>
              </a></li>
            )}
            {!docs.length && !magazine && <li><div className="muted">{t(lang, "Speeches and communiqués are published here as they are released.", "Les discours et communiqués sont publiés ici dès leur parution.")}</div></li>}
            <li><Link href="/media-centre#documents"><span className="h3 h3--sm">{t(lang, "All documents and publications", "Tous les documents et publications")}</span><span aria-hidden="true">→</span></Link></li>
          </ul>
        </div>
      </section>
    </>
  );
}
