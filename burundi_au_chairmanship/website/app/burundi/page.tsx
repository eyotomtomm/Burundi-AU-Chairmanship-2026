import type { Metadata } from "next";
import Link from "next/link";
import { api, media } from "@/lib/api";
import { getLang, t, tr } from "@/lib/i18n";
import { AfricaMap } from "@/components/AfricaMap";
import { Band } from "@/components/Band";
import { Crumbs, SectionHead } from "@/components/ui";

export const metadata: Metadata = {
  title: "Discover Burundi",
  description: "Geography, history, culture, places to see and national symbols of Burundi, the heart of Africa.",
};

export default async function Discover() {
  const lang = await getLang();
  const [facts, resources] = await Promise.all([api.facts(), api.resources()]);
  const guides = resources.results.filter((r) => r.category === "country_info");

  const milestones: Array<[string, string, string]> = [
    ["1903", "Treaty of Kiganda between German forces and Mwami Mwezi Gisabo.", "Traité de Kiganda entre les forces allemandes et le Mwami Mwezi Gisabo."],
    ["1919", "Belgium receives the mandate over Ruanda-Urundi at the Versailles conference.", "La Belgique reçoit le mandat sur le Ruanda-Urundi à la conférence de Versailles."],
    ["1962", "Independence proclaimed on 1 July, now the National Day.", "Indépendance proclamée le 1er juillet, aujourd’hui fête nationale."],
    ["1966", "Proclamation of the First Republic on 28 November.", "Proclamation de la Première République le 28 novembre."],
    ["1991", "Adoption of the Charter of National Unity on 5 February.", "Adoption de la Charte de l’Unité nationale le 5 février."],
    ["2000", "Arusha Agreement for Peace and Reconciliation signed on 28 August.", "Signature de l’Accord d’Arusha pour la paix et la réconciliation le 28 août."],
    ["2019", "Gitega becomes the political capital on 4 February.", "Gitega devient la capitale politique le 4 février."],
    ["2026", "Burundi takes the chair of the African Union.", "Le Burundi prend la présidence de l’Union africaine."],
  ];
  const places: Array<[string, string, string, string?]> = [
    ["/img/karera-falls.jpg", "Karera Falls", "Karera waterfalls"],
    ["/img/gitega-museum.jpg", "Gitega National Museum", "The National Museum of Gitega"],
    ["/img/rusizi-hippos.jpg", "Rusizi River", "Hippos on the bank of the Rusizi"],
    ["/img/lake-tanganyika.jpg", "Lake Tanganyika", "Lake Tanganyika", "20% center"],
    ["/img/drummers.jpg", "Gishora drum sanctuary", "Burundian drummers", "38% center"],
    ["/img/dancers.jpg", "Faille des Allemands", "Dancers in green and red holding woven baskets", "58% center"],
  ];
  const hotels = ["Hôtel Club du Lac Tanganyika", "Hôtel Royale Palace", "Kiriri Garden Hotel", "Eden Garden Resort", "Hôtel de la Palmeraie", "Best Outlook Hotel", "Hôtel Dolce Vita Resort", "Roca Golf Hotel", "Hôtel Kangaroo", "King’s Conference Center"];
  const holidays: Array<[string, string, string, string]> = [
    ["8 March", "8 mars", "International Women’s Day", "Journée internationale des femmes"],
    ["6 April", "6 avril", "President Cyprien Ntaryamira", "Président Cyprien Ntaryamira"],
    ["1 May", "1er mai", "Labour Day", "Fête du travail"],
    ["1 July", "1er juillet", "Independence Day", "Fête de l’indépendance"],
    ["13 October", "13 octobre", "Prince Louis Rwagasore", "Prince Louis Rwagasore"],
    ["21 October", "21 octobre", "President Melchior Ndadaye", "Président Melchior Ndadaye"],
  ];

  return (
    <>
      <section style={{ position: "relative", background: "var(--white)" }}>
        <div className="fig" style={{ borderRadius: 0, height: "clamp(320px, 45vw, 620px)" }}>
          <img src="/img/lake-tanganyika.jpg" alt="Green hills along the shore of Lake Tanganyika" style={{ objectPosition: "center 55%" }} />
          <span className="cap-pill" style={{ left: "auto", right: 20, bottom: 20 }}>Lake Tanganyika</span>
        </div>
        <div className="wrap">
          <div className="stack stack--sm" style={{ maxWidth: 760, background: "var(--white)", borderRadius: "28px 28px 0 0", padding: "40px 44px 8px", marginTop: -120, position: "relative" }}>
            <Crumbs lang={lang} items={[["Burundi"]]} />
            <h1 className="h1">{lang === "fr" ? <>Le Burundi, <em className="hl">cœur de l’Afrique</em></> : <>Burundi, the <em className="hl">heart of Africa</em></>}</h1>
            <p className="lede">{t(lang, "South of the Equator, between the Congo basin and the eastern highlands, at the crossroads of Central, East and Southern Africa.", "Au sud de l’Équateur, entre le bassin du Congo et les hauts plateaux de l’Est, au carrefour de l’Afrique centrale, orientale et australe.")}</p>
          </div>
        </div>
      </section>

      <section className="sec" id="geography">
        <div className="wrap stack stack--lg">
          <dl className="stats" style={{ borderTop: "2px solid var(--ink)", paddingTop: 28 }}>
            <div><dt>27,834<small> km²</small></dt><dd>{t(lang, "Total area, 2,180 km² of it water", "Superficie totale, dont 2 180 km² d’eau")}</dd></div>
            <div><dt>974<small> km</small></dt><dd>{t(lang, "Borders: DR Congo 233, Rwanda 290, Tanzania 451", "Frontières : RD Congo 233, Rwanda 290, Tanzanie 451")}</dd></div>
            <div><dt>2,684<small> m</small></dt><dd>{t(lang, "Highest point, south-east of Mount Heha", "Point culminant, au sud-est du mont Heha")}</dd></div>
            <div><dt>17–23<small> °C</small></dt><dd>{t(lang, "Average yearly temperature", "Température moyenne annuelle")}</dd></div>
            <div><dt>1,500<small> mm</small></dt><dd>{t(lang, "Average yearly rainfall", "Précipitations moyennes annuelles")}</dd></div>
          </dl>
          <div className="grid grid--center">
            <div className="span-7 cols cols-3" style={{ gap: 40 }}>
              <div className="stack" style={{ gap: 10 }}><h3 className="h3">{t(lang, "Two capitals", "Deux capitales")}</h3><p className="muted">{t(lang, "Bujumbura, the economic capital, sits on the shore of Lake Tanganyika. Gitega has been the political capital since 4 February 2019, home of the National Museum and the drum sanctuaries of Gishora, Higiro and Kidasha.", "Bujumbura, capitale économique, borde le lac Tanganyika. Gitega est la capitale politique depuis le 4 février 2019 ; elle abrite le Musée national et les sanctuaires des tambours de Gishora, Higiro et Kidasha.")}</p></div>
              <div className="stack" style={{ gap: 10 }}><h3 className="h3">{t(lang, "Lakes and rivers", "Lacs et rivières")}</h3><p className="muted">{t(lang, "Lake Tanganyika, shared with Tanzania, DR Congo and Zambia, is the second deepest lake in the world. The Rusizi, Malagarazi and Ruvubu are the main rivers, and Gasumo, in Bururi, is the southernmost source of the Nile.", "Le lac Tanganyika, partagé avec la Tanzanie, la RD Congo et la Zambie, est le deuxième lac le plus profond du monde. La Rusizi, la Malagarazi et la Ruvubu sont les principales rivières ; Gasumo, à Bururi, est la source la plus méridionale du Nil.")}</p></div>
              <div className="stack" style={{ gap: 10 }}><h3 className="h3">{t(lang, "Seasons", "Saisons")}</h3><p className="muted">{t(lang, "An equatorial highland climate with rains from February to May and from September to November. Hills and mountains cross the Congo–Nile divide, with a few plains to the east.", "Un climat équatorial d’altitude, avec des pluies de février à mai et de septembre à novembre. Collines et montagnes suivent la crête Congo-Nil, avec quelques plaines à l’est.")}</p></div>
            </div>
            <figure className="span-4 start-9 hero-map"><AfricaMap /></figure>
          </div>
        </div>
      </section>

      <section className="sec sec--ivory" id="history">
        <div className="wrap grid">
          <div className="span-4 stack" style={{ gap: 10 }}>
            <span className="eyebrow">{t(lang, "History", "Histoire")}</span>
            <h2 className="h2">{t(lang, "Milestones", "Repères")}</h2>
            <p className="muted">{t(lang, "A short timeline.", "Une brève chronologie.")}</p>
          </div>
          <ol className="span-7 start-6 rule-list">
            {milestones.map(([year, en, fr]) => (
              <li key={year}>
                <div style={{ display: "grid", gridTemplateColumns: "150px 1fr", gap: 24, justifyContent: "start" }}>
                  <span className="display" style={{ fontSize: 34, color: year === "2026" ? "var(--gold-ink)" : undefined }}>{year}</span>
                  <span>{t(lang, en, fr)}</span>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <Band />

      <section className="sec" id="culture">
        <div className="wrap grid grid--center">
          <figure className="span-6 fig" style={{ height: 520 }}><img src="/img/drummers.jpg" alt="Burundian drummers and a dancer with a shield in the national colours" style={{ objectPosition: "38% center" }} loading="lazy" /></figure>
          <div className="span-5 start-8 stack" style={{ gap: 18 }}>
            <span className="eyebrow">Culture</span>
            <h2 className="h2 h2--md">{t(lang, "One language, many voices", "Une langue, plusieurs voix")}</h2>
            <p className="muted" style={{ lineHeight: 1.7 }}>{t(lang, "Everyone in Burundi speaks the national language, Kirundi. French is the first foreign language, English is growing, and Swahili is spoken in towns and along Lake Tanganyika.", "Tout le monde au Burundi parle la langue nationale, le kirundi. Le français est la première langue étrangère, l’anglais progresse et le swahili se parle dans les villes et le long du lac Tanganyika.")}</p>
            <p className="muted" style={{ lineHeight: 1.7 }}>{t(lang, "Songs, dances, tales and legends carry the culture. Herders sing pastoral songs at dusk, and elders pass stories of the ancestors to the young. Basketry, masks, shields, statues and pottery are the crafts; drums are almost spiritual.", "Chants, danses, contes et légendes portent la culture. Les bergers chantent au crépuscule et les anciens transmettent l’histoire des ancêtres aux jeunes. Vannerie, masques, boucliers, statues et poterie sont les artisanats ; le tambour est presque sacré.")}</p>
            <p className="muted" style={{ lineHeight: 1.7 }}>{t(lang, "Staple foods are potatoes, bananas, beans and sometimes fish.", "Pommes de terre, bananes, haricots et parfois poisson composent l’alimentation de base.")}</p>
          </div>
        </div>
      </section>

      {facts.results.length > 0 && (
        <section className="sec sec--dark">
          <div className="wrap stack">
            <SectionHead light eyebrow={t(lang, "Did you know", "Le saviez-vous")} title={t(lang, "Facts and voices", "Faits et paroles")} />
            <div className="cols cols-3">
              {facts.results.slice(0, 6).map((f) => (
                <article key={f.id} className="card card--flush" style={{ background: "rgba(255,255,255,0.06)", borderColor: "rgba(255,255,255,0.14)", color: "#fff" }}>
                  {f.image && <img src={media(f.image)} alt="" loading="lazy" style={{ width: "100%", aspectRatio: "16/9", objectFit: "cover" }} />}
                  <div className="card-body">
                    {f.category && <span className="eyebrow eyebrow--gold" style={{ fontSize: 14 }}>{tr(f.category, "name", lang)}</span>}
                    {f.fact_type === "quote" ? (
                      <blockquote className="ital" style={{ fontSize: 22, lineHeight: 1.35 }}>“{tr(f, "content_preview", lang) || tr(f, "title", lang)}”</blockquote>
                    ) : (
                      <><h3 className="h3 h3--sm">{tr(f, "title", lang)}</h3><p style={{ color: "#C9D9C6" }}>{tr(f, "content_preview", lang)}</p></>
                    )}
                    {(f.author_name || f.source) && <span className="small" style={{ color: "#A7BFA9" }}>{f.author_name ? `${f.author_name}${tr(f, "author_title", lang) ? ` · ${tr(f, "author_title", lang)}` : ""}` : tr(f, "source", lang)}</span>}
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>
      )}

      <section className="sec sec--ivory" id="places">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "Tourism", "Tourisme")} title={lang === "fr" ? <>À <em className="ital">voir</em></> : <>Places to <em className="ital">see</em></>} more={t(lang, "Travel & emergency", "Voyage & urgences")} moreHref="/travel" />
          <div className="places" style={{ gridTemplateColumns: "repeat(3, minmax(0, 1fr))" }}>
            {places.map(([src, title, alt, pos]) => (
              <figure key={title} className="stack" style={{ gap: 10 }}>
                <span className="fig" style={{ height: 300 }}><img src={src} alt={alt} style={pos ? { objectPosition: pos } : undefined} loading="lazy" /></span>
                <figcaption className="display" style={{ fontSize: 26 }}>{title}</figcaption>
              </figure>
            ))}
          </div>
          <div className="chips">
            {["Ruvubu National Park", "Lac aux oiseaux", "Rusizi National Park", "Source du Nil (Gasumo)"].map((p) => <span key={p} className="chip">{p}</span>)}
          </div>
        </div>
      </section>

      <section className="sec" id="hotels">
        <div className="wrap grid">
          <div className="span-4 stack" style={{ gap: 10 }}>
            <span className="eyebrow">{t(lang, "Where to stay", "Où loger")}</span>
            <h2 className="h2">{t(lang, "Hotels in Bujumbura", "Hôtels à Bujumbura")}</h2>
            <p className="muted">{t(lang, "Links open a web search for the hotel.", "Les liens ouvrent une recherche web pour l’hôtel.")}</p>
          </div>
          <ul className="span-7 start-6 cols cols-2" style={{ gap: "0 32px", borderTop: "2px solid var(--ink)" }}>
            {hotels.map((h) => (
              <li key={h}>
                <a href={`https://www.google.com/search?q=${encodeURIComponent(h + " Bujumbura")}`} rel="noopener" className="display" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", minHeight: 56, padding: "12px 0", borderBottom: "1px solid var(--line)", fontSize: 21 }}>
                  {h}<span aria-hidden="true">↗</span>
                </a>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="sec sec--ivory" id="symbols">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "National symbols", "Symboles nationaux")} title={t(lang, "Flag, arms, anthem, holidays", "Drapeau, armoiries, hymne, fêtes")} />
          <div className="cols cols-3">
            <div className="card" style={{ gap: 16 }}>
              <svg role="img" aria-label={t(lang, "Flag of Burundi", "Drapeau du Burundi")} viewBox="0 0 360 216" style={{ width: "100%", height: 176, borderRadius: 6 }}>
                <polygon points="0,0 360,0 180,108" fill="#CE1126" /><polygon points="0,216 360,216 180,108" fill="#CE1126" />
                <polygon points="0,0 0,216 180,108" fill="#1EB53A" /><polygon points="360,0 360,216 180,108" fill="#1EB53A" />
                <line x1="0" y1="0" x2="360" y2="216" stroke="#FFFFFF" strokeWidth="30" /><line x1="360" y1="0" x2="0" y2="216" stroke="#FFFFFF" strokeWidth="30" />
                <circle cx="180" cy="108" r="56" fill="#FFFFFF" />
                <g fill="#CE1126" stroke="#1EB53A" strokeWidth="1.5">
                  <polygon points="180.0,73.0 183.8,79.5 191.3,79.5 187.5,86.0 191.3,92.5 183.8,92.5 180.0,99.0 176.2,92.5 168.7,92.5 172.5,86.0 168.7,79.5 176.2,79.5" />
                  <polygon points="163.0,101.0 166.8,107.5 174.3,107.5 170.5,114.0 174.3,120.5 166.8,120.5 163.0,127.0 159.2,120.5 151.7,120.5 155.5,114.0 151.7,107.5 159.2,107.5" />
                  <polygon points="197.0,101.0 200.8,107.5 208.3,107.5 204.5,114.0 208.3,120.5 200.8,120.5 197.0,127.0 193.2,120.5 185.7,120.5 189.5,114.0 185.7,107.5 193.2,107.5" />
                </g>
              </svg>
              <h3 className="h3 h3--sm">{t(lang, "The flag", "Le drapeau")}</h3>
              <p className="small muted">{t(lang, "A white saltire divides it into four: red above and below, green at the hoist and the fly. In the white disc at the centre, three red six-pointed stars edged in green.", "Un sautoir blanc le divise en quatre : rouge en haut et en bas, vert à la hampe et au battant. Dans le disque blanc central, trois étoiles rouges à six branches bordées de vert.")}</p>
            </div>
            <div className="card" style={{ gap: 16 }}>
              <div style={{ height: 176, display: "flex", alignItems: "center", justifyContent: "center" }}><img src="/img/coat-of-arms.png" alt={t(lang, "Coat of arms of Burundi", "Armoiries du Burundi")} width={170} height={170} loading="lazy" /></div>
              <h3 className="h3 h3--sm">{t(lang, "Arms and motto", "Armoiries et devise")}</h3>
              <p className="small muted">Unité · Travail · Progrès. {t(lang, "Unity, Work, Progress.", "Unité, Travail, Progrès.")}</p>
              <div className="stack" style={{ gap: 4, marginTop: 8, paddingTop: 16, borderTop: "1px solid var(--line)" }}><span className="ital" style={{ fontSize: 22 }}>Burundi Bwacu</span><span className="small muted">{t(lang, "National anthem since 1962. Words by Jean-Baptiste Ntahokaja, music by Marc Barengayabo.", "Hymne national depuis 1962. Paroles de Jean-Baptiste Ntahokaja, musique de Marc Barengayabo.")}</span></div>
            </div>
            <div className="card">
              <h3 className="h3 h3--sm">{t(lang, "Public holidays", "Jours fériés")}</h3>
              <dl className="dl small">
                {holidays.map(([en, fr, nameEn, nameFr]) => <span key={en} style={{ display: "contents" }}><dt>{t(lang, en, fr)}</dt><dd>{t(lang, nameEn, nameFr)}</dd></span>)}
              </dl>
            </div>
          </div>
        </div>
      </section>

      {guides.length > 0 && (
        <section className="sec">
          <div className="wrap stack">
            <SectionHead eyebrow={t(lang, "Downloads", "Téléchargements")} title={t(lang, "Guides to Burundi", "Guides du Burundi")} more={t(lang, "All documents", "Tous les documents")} moreHref="/media#documents" />
            <ul className="rule-list rule-list--strong">
              {guides.map((r) => (
                <li key={r.id}><a href={media(r.file)} rel="noopener"><span className="h3 h3--sm">{tr(r, "title", lang)}</span><span className="badge-pdf">{r.file_type.toUpperCase()} · {r.file_size} ↓</span></a></li>
              ))}
            </ul>
          </div>
        </section>
      )}

      <section className="sec sec--dark">
        <div className="wrap grid grid--center">
          <div className="span-7 stack" style={{ gap: 14 }}>
            <span className="eyebrow eyebrow--gold">{t(lang, "Invest in Burundi", "Investir au Burundi")}</span>
            <h2 className="h2 h2--md">{t(lang, "Finance for young and women-led projects", "Financer les projets des jeunes et des femmes")}</h2>
            <p style={{ fontSize: 17, lineHeight: 1.7, color: "#C9D9C6" }}>{t(lang, "Dedicated banks now finance projects led by young people (BIJE, 2019) and by women (BIDF, 2020). Since 2020, commercial banks refinance at 2% with a maximum 6% margin, bringing investment loans to 8% at most.", "Des banques dédiées financent désormais les projets des jeunes (BIJE, 2019) et des femmes (BIDF, 2020). Depuis 2020, les banques commerciales se refinancent à 2 % avec une marge maximale de 6 %, soit des crédits d’investissement à 8 % au plus.")}</p>
          </div>
          <div className="span-4 start-9 stack" style={{ gap: 12 }}>
            <a className="btn btn--gold btn--md" href="https://investburundi.bi" rel="noopener" style={{ justifyContent: "space-between" }}>investburundi.bi<span aria-hidden="true">↗</span></a>
            <Link className="btn btn--ghost btn--md" href="/invest#texts" style={{ justifyContent: "space-between" }}>{t(lang, "Investment Code", "Code des investissements")}<span aria-hidden="true">→</span></Link>
            <Link className="btn btn--ghost btn--md" href="/invest" style={{ justifyContent: "space-between" }}>{t(lang, "Financial services in Burundi", "Services financiers au Burundi")}<span aria-hidden="true">→</span></Link>
          </div>
        </div>
      </section>
    </>
  );
}
