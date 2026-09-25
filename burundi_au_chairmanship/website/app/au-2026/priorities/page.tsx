import type { Metadata } from "next";
import Link from "next/link";
import { api, media } from "@/lib/api";
import { excerpt, fmtDate, getLang, paragraphs, t, tr } from "@/lib/i18n";
import type { Lang, PriorityAgenda } from "@/lib/types";
import { Crumbs, Empty, Ico, ICONS, SectionHead } from "@/components/ui";

export const metadata: Metadata = {
  title: "AU 2026 · Priority agenda",
  description: "The three priorities of Burundi’s AU Chairmanship: Water & Sanitation, the A-RISE Initiative, and Peace & Security. Objectives, impact areas and current initiatives.",
};

const FALLBACK_THEME = "Assuring Sustainable Water Availability and Safe Sanitation Systems to Achieve the Goals of Agenda 2063";
const FALLBACK_IMG = ["/img/lake-tanganyika.jpg", "/img/president-youth.jpg", "/img/handshake.jpg"];
const ICON = [ICONS.drop, ICONS.rise, ICONS.shield];
const ORD_EN = ["one", "two", "three", "four", "five"];
const ORD_FR = ["un", "deux", "trois", "quatre", "cinq"];

function Prose({ text }: { text: string }) {
  return (
    <div className="prose">
      {paragraphs(text).map((b, i) =>
        b.type === "ul" ? <ul key={i}>{b.lines.map((l) => <li key={l}>{l}</li>)}</ul> : <p key={i}>{b.lines.join(" ")}</p>,
      )}
    </div>
  );
}

function Priority({ a, i, lang }: { a: PriorityAgenda; i: number; lang: Lang }) {
  const objectives = (lang === "fr" && a.objectives_fr?.length ? a.objectives_fr : a.objectives) ?? [];
  const areas = (lang === "fr" && a.impact_areas_fr?.length ? a.impact_areas_fr : a.impact_areas) ?? [];
  const overview = tr(a, "overview", lang);
  const initiatives = tr(a, "current_initiatives", lang);
  const img = media(a.hero_image) || FALLBACK_IMG[i % 3];
  return (
    <section id={a.slug} className={`sec${i % 2 ? " sec--ivory" : ""}`}>
      <div className="wrap stack stack--lg">
        <header className="between" style={{ alignItems: "flex-end", borderBottom: "2px solid var(--ink)", paddingBottom: 24 }}>
          <div className="row" style={{ gap: 24, alignItems: "baseline" }}>
            <span className="num display" style={{ fontSize: "clamp(56px, 7vw, 110px)", lineHeight: 1 }} aria-hidden="true">{String(i + 1).padStart(2, "0")}</span>
            <div className="stack" style={{ gap: 4 }}>
              <span className="eyebrow">{lang === "fr" ? `Priorité ${ORD_FR[i] ?? i + 1}` : `Priority ${ORD_EN[i] ?? i + 1}`}</span>
              <h2 className="h2">{tr(a, "title", lang)}</h2>
            </div>
          </div>
          <Link className="more arrow" href="/events">{t(lang, "Dialogue and events", "Dialogue et événements")}</Link>
        </header>
        <p className="lede">{tr(a, "description", lang)}</p>
        <div className="grid">
          <div className="span-7 stack">
            {overview && <><h3 className="h3">{t(lang, "Overview", "Aperçu")}</h3><Prose text={overview} /></>}
            {objectives.length > 0 && (
              <>
                <div className="between" style={{ alignItems: "baseline" }}><h3 className="h3">{t(lang, "Key objectives", "Objectifs clés")}</h3><span className="meta">{objectives.length} {t(lang, "objectives", "objectifs")}</span></div>
                <ol className="rule-list">
                  {objectives.map((o, n) => <li key={n}><div style={{ justifyContent: "flex-start", gap: 18 }}><span className="num" style={{ minWidth: 32 }}>{String(n + 1).padStart(2, "0")}</span><span style={{ fontSize: 17 }}>{o}</span></div></li>)}
                </ol>
              </>
            )}
          </div>
          <div className="span-5 stack">
            <figure className="fig fig--4x3"><img src={img} alt="" loading="lazy" /></figure>
            {initiatives && <div className="panel" style={{ background: i % 2 ? "var(--white)" : "var(--ivory)", padding: 28 }}><h3 className="h3 h3--sm">{t(lang, "Current initiatives", "Initiatives en cours")}</h3><Prose text={initiatives} /></div>}
          </div>
        </div>
        {areas.length > 0 && (
          <>
            <div className="between" style={{ alignItems: "baseline" }}><h3 className="h3">{t(lang, "Impact areas", "Domaines d’impact")}</h3><span className="meta">{areas.length} {t(lang, "focus areas", "domaines")}</span></div>
            <div className="cols cols-4">
              {areas.map((ar) => <div key={ar.title} className="card"><span className="icon-circle"><Ico d={ICON[i % 3]} /></span><h4 className="h3 h3--sm">{ar.title}</h4><p className="small muted">{ar.description}</p></div>)}
            </div>
          </>
        )}
      </div>
    </section>
  );
}

export default async function PrioritiesPage() {
  const lang = await getLang();
  const [agendas, categories, settings] = await Promise.all([api.agendas(), api.categories(), api.settings()]);
  const au = categories.find((c) => /chairmanship|présidence/i.test(c.name));
  const news = await api.articles({ category: au?.id, page_size: 6 });
  const theme = settings && settings.summit_theme.length > 3 ? tr(settings, "summit_theme", lang) : FALLBACK_THEME;

  return (
    <>
      <section className="page-hero">
        <div className="wrap grid grid--center">
          <div className="span-6 stack" style={{ gap: 24 }}>
            <Crumbs lang={lang} items={[["AU 2026", "/au-2026"], [t(lang, "Priority agenda", "Agenda prioritaire")]]} />
            <h1 className="h1">{lang === "fr" ? <>Trois priorités pour <em className="hl">l’Union africaine</em></> : <>Three priorities for <em className="hl">the African Union</em></>}</h1>
            <p className="lede">{t(lang, "Burundi’s chairmanship of the African Union is built on three priorities. Each one has its own programme, objectives and current work.", "La présidence burundaise de l’Union africaine repose sur trois priorités. Chacune a son programme, ses objectifs et ses travaux en cours.")}</p>
            <div className="panel" style={{ background: "var(--ivory)" }}><span className="eyebrow" style={{ fontSize: 14 }}>{t(lang, "AU theme of the year 2026", "Thème de l’année 2026 de l’UA")}</span><span className="ital" style={{ fontSize: 18, lineHeight: 1.4 }}>{theme}</span></div>
            <div className="row btn-row"><a className="btn" href="#index">{t(lang, "The three priorities", "Les trois priorités")}</a><Link className="btn btn--outline" href="/au-2026">{t(lang, "The chairmanship", "La présidence")}</Link></div>
          </div>
          <div className="span-5 start-8 stack" style={{ gap: 14 }}>
            <figure className="fig fig--4x3"><img src="/img/president-podium.jpg" alt="President Évariste Ndayishimiye speaking at the African Union podium" /><figcaption className="cap-pill">{t(lang, "At the African Union podium", "À la tribune de l’Union africaine")}</figcaption></figure>
            <figure className="fig fig--16x9"><img src="/img/president-youth.jpg" alt="President Évariste Ndayishimiye with young delegates" loading="lazy" style={{ objectPosition: "center 30%" }} /></figure>
            <p className="caption">{t(lang, "With young delegates at the 5th Continental Dialogue on Youth, Peace & Security, Bujumbura, August 2026.", "Avec de jeunes délégués au 5e Dialogue continental sur la jeunesse, la paix et la sécurité, Bujumbura, août 2026.")}</p>
          </div>
        </div>
      </section>

      <section id="index" className="sec sec--dark">
        <div className="wrap stack">
          <SectionHead light eyebrow={t(lang, "The priority agenda", "L’agenda prioritaire")} title={t(lang, "Three doors into the agenda", "Trois portes d’entrée dans l’agenda")} />
          <p className="lede lede--sm" style={{ color: "#C9D9C6" }}>{t(lang, "Select a priority to read its objectives, impact areas and current initiatives.", "Choisissez une priorité pour lire ses objectifs, ses domaines d’impact et ses initiatives en cours.")}</p>
          {agendas.length ? (
            <div className="cols cols-3">
              {agendas.map((a, i) => (
                <a key={a.id} className="card" style={{ background: "rgba(255,255,255,0.06)", borderColor: "rgba(255,255,255,0.16)", color: "#fff", minHeight: 260 }} href={`#${a.slug}`}>
                  <span className="tag tag--gold" style={{ alignSelf: "flex-start" }}>{t(lang, "Priority", "Priorité")} {String(i + 1).padStart(2, "0")}</span>
                  <h3 className="h3 h3--lg">{tr(a, "title", lang)}</h3>
                  <p style={{ color: "#C9D9C6" }}>{tr(a, "description", lang)}</p>
                  <span className="push bold arrow" style={{ color: "var(--gold)" }}>{t(lang, "Read the priority", "Lire la priorité")}</span>
                </a>
              ))}
            </div>
          ) : <Empty>{t(lang, "The priorities will be published here.", "Les priorités seront publiées ici.")}</Empty>}
        </div>
      </section>

      {agendas.map((a, i) => <Priority key={a.id} a={a} i={i} lang={lang} />)}

      <section className="sec" style={{ borderTop: "1px solid var(--line)" }}>
        <div className="wrap stack stack--lg">
          <SectionHead eyebrow={t(lang, "Roundtable on Burundi’s Presidency of the AU · 9 June 2026", "Table ronde sur la Présidence burundaise de l’UA · 9 juin 2026")} title={t(lang, "Four areas of the presidency", "Quatre axes de la présidence")} />
          <div className="grid">
            <div className="span-7 stack">
              <p className="lede lede--sm">{t(lang, "On 9 June 2026, Foreign Minister Amb. Édouard Bizimana opened a roundtable with government, the diplomatic corps, partners, the private sector, civil society, universities, youth and the media.", "Le 9 juin 2026, le ministre des Affaires étrangères, l’Amb. Édouard Bizimana, a ouvert une table ronde avec le gouvernement, le corps diplomatique, les partenaires, le secteur privé, la société civile, les universités, la jeunesse et les médias.")}</p>
              <ol className="rule-list">
                {[t(lang, "Water sustainability and climate resilience", "Durabilité de l’eau et résilience climatique"), t(lang, "Regional security and conflict prevention", "Sécurité régionale et prévention des conflits"), t(lang, "Inclusive education and youth empowerment", "Éducation inclusive et autonomisation des jeunes"), t(lang, "Women’s economic and political participation", "Participation économique et politique des femmes")].map((s, n) => (
                  <li key={s}><div style={{ justifyContent: "flex-start", gap: 18 }}><span className="num">{String(n + 1).padStart(2, "0")}</span><span className="h3 h3--sm">{s}</span></div></li>
                ))}
              </ol>
              <blockquote className="quote" style={{ fontSize: "clamp(24px, 2.6vw, 34px)" }}>{t(lang, "“A mark of confidence from the Member States.”", "« Une marque de confiance des États membres. »")}</blockquote>
              <p className="small muted">{t(lang, "Amb. Édouard Bizimana, Minister of Foreign Affairs, describing Burundi’s AU presidency at the Roundtable of 9 June 2026. The Minister presented the presidency as Burundi’s return to the international stage, with opportunities to represent Africa in forums such as the G20 and the United Nations.", "L’Amb. Édouard Bizimana, ministre des Affaires étrangères, à propos de la présidence burundaise de l’UA lors de la table ronde du 9 juin 2026. Le ministre a présenté la présidence comme le retour du Burundi sur la scène internationale, avec l’occasion de représenter l’Afrique dans des forums tels que le G20 et les Nations unies.")}</p>
            </div>
            <aside className="span-4 start-9 stack">
              <div className="card card--gold"><span className="display" style={{ fontSize: 48, lineHeight: 1 }}>$13 million</span><span className="small">{t(lang, "approved by the African Development Bank to assist refugees in Burundi, as noted at the partners’ meeting of 1 June 2026.", "approuvés par la Banque africaine de développement pour aider les réfugiés au Burundi, comme relevé à la réunion des partenaires du 1er juin 2026.")}</span></div>
              <div className="card card--ivory">
                <span className="eyebrow" style={{ fontSize: 14 }}>{t(lang, "Presented to partners · 1 June 2026", "Présenté aux partenaires · 1er juin 2026")}</span>
                <p className="small muted">{t(lang, "Set out by the Foreign Minister to the UN, the EU, the World Bank and the African Development Bank.", "Exposé par le ministre des Affaires étrangères à l’ONU, à l’UE, à la Banque mondiale et à la Banque africaine de développement.")}</p>
                <ol className="stack stack--sm">
                  {[t(lang, "Continental Youth Dialogue on Peace and Security", "Dialogue continental des jeunes sur la paix et la sécurité"), t(lang, "Women and girls empowerment", "Autonomisation des femmes et des filles"), t(lang, "Water, sanitation, and living conditions improvements", "Eau, assainissement et amélioration des conditions de vie"), t(lang, "Education access for refugee children", "Accès à l’éducation pour les enfants réfugiés")].map((s, n) => <li key={s} className="row" style={{ gap: 12 }}><span className="num">{n + 1}</span><span>{s}</span></li>)}
                </ol>
              </div>
            </aside>
          </div>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "Newsroom", "Actualités")} title={t(lang, "The agenda in the news", "L’agenda dans l’actualité")} more={t(lang, "All news", "Toutes les actualités")} moreHref={au ? `/news?category=${au.id}` : "/news"} />
          {news.results.length ? (
            <div className="cols cols-3">
              {news.results.map((a) => (
                <Link key={a.id} className="card card--flush news-card" href={`/news/${a.id}`}>
                  <img src={media(a.medium_url || a.image) || "/img/au-hq.jpg"} alt="" loading="lazy" />
                  <div className="card-body" style={{ padding: 24 }}>
                    <span className="meta">{a.category ? `${tr(a.category, "name", lang)} · ` : ""}{fmtDate(a.publish_date, lang)}</span>
                    <h3 className="h3 h3--sm">{tr(a, "title", lang)}</h3>
                    <p className="small muted">{excerpt(tr(a, "content", lang), 28)}</p>
                    <span className="push bold arrow">{t(lang, "Read the article", "Lire l’article")}</span>
                  </div>
                </Link>
              ))}
            </div>
          ) : <Empty>{t(lang, "No related news yet.", "Pas encore d’actualité liée.")}</Empty>}
        </div>
      </section>
    </>
  );
}
