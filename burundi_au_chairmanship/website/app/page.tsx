import Link from "next/link";
import { api, media } from "@/lib/api";
import { excerpt, fmtDate, getLang, t, tr } from "@/lib/i18n";
import { AfricaMap } from "@/components/AfricaMap";
import { Band } from "@/components/Band";
import { SectionHead, Empty, PlayIcon, Ico, ICONS } from "@/components/ui";

export default async function Home() {
  const lang = await getLang();
  const now = new Date();
  const [news, categories, agendas, live, events, settings] = await Promise.all([
    api.articles({ page_size: 6 }),
    api.categories(),
    api.agendas(),
    api.live(),
    api.events({ page_size: 20 }),
    api.settings(),
  ]);
  const [featured, ...rest] = news.results;
  const liveNow = live.results.find((l) => l.status === "live") ?? null;
  const upcoming = events.results
    .filter((e) => new Date(e.event_date) >= now)
    .sort((a, b) => a.event_date.localeCompare(b.event_date))
    .slice(0, 3);
  const theme = settings && settings.summit_theme.length > 3 ? tr(settings, "summit_theme", lang)
    : "Assuring Sustainable Water Availability and Safe Sanitation Systems to Achieve the Goals of Agenda 2063";

  const services = [
    { href: "/services#visa", icon: ICONS.doc, title: "Visa", body: t(lang, "Eleven visa types, from transit to permanent residence.", "Onze types de visa, du transit à la résidence permanente."), foot: t(lang, "Several free · Transit 40 USD", "Plusieurs gratuits · Transit 40 USD") },
    { href: "/services#passport", icon: ICONS.passport, title: t(lang, "Passport", "Passeport"), body: t(lang, "Ordinary, service and diplomatic passports.", "Passeports ordinaire, de service et diplomatique."), foot: `235,000 FBU · 10 ${t(lang, "years", "ans")}` },
    { href: "/services#laissez-passer", icon: ICONS.send, title: "Laissez-passer", body: t(lang, "For Burundians travelling within the EAC.", "Pour les Burundais voyageant dans l’EAC."), foot: `30,000 FBU · 1 ${t(lang, "year", "an")}` },
    { href: "/services#cepgl", icon: ICONS.link, title: t(lang, "CEPGL card", "Carte CEPGL"), body: t(lang, "Travel within the Great Lakes countries.", "Circuler dans les pays des Grands Lacs."), foot: `18,000 FBU · 1 ${t(lang, "year", "an")}` },
  ];
  const places = [
    ["/img/karera-falls.jpg", "Karera Falls", "Karera waterfalls", ""],
    ["/img/drummers.jpg", "Gishora drum sanctuary", "Burundian drummers", "38% center"],
    ["/img/lake-tanganyika.jpg", "Lake Tanganyika", "Green hills above Lake Tanganyika", "30% center"],
    ["/img/gitega-museum.jpg", "Gitega National Museum", "The National Museum of Gitega", ""],
  ];

  return (
    <>
      <section className="hero">
        <div className="wrap">
          <div className="hero-copy">
            <span className="pill"><span className="dot dot--ring" />Addis Ababa · {fmtDate(now.toISOString(), lang)}</span>
            <h1 className="h1">
              {lang === "fr"
                ? <>Au <em className="hl">cœur de l’Afrique</em>, et à la tête de son Union.</>
                : <>At the <em className="hl">heart of Africa</em>, and at the head of its Union.</>}
            </h1>
            <p className="lede">
              {t(lang,
                "The Embassy of the Republic of Burundi in Addis Ababa, and its Permanent Mission to the African Union and UNECA. Consular services, news and support for Burundians and visitors.",
                "L’Ambassade de la République du Burundi à Addis-Abeba et sa Mission permanente auprès de l’Union africaine et de la CEA. Services consulaires, actualités et assistance aux Burundais et aux visiteurs.")}
            </p>
            <div className="row btn-row">
              <Link className="btn" href="/services">{t(lang, "Consular services", "Services consulaires")}<Ico d={ICONS.arrow} size={18} stroke="currentColor" /></Link>
              <Link className="btn btn--outline" href="/au-2026"><span className="dot" />{t(lang, "The 2026 chairmanship", "La présidence 2026")}</Link>
            </div>
            <span className="sc muted" style={{ fontSize: 15 }}>{t(lang, "Accredited to", "Accrédité auprès de")} Ethiopia · Chad · Djibouti · Eritrea · South Sudan · Israel · AU · UNECA</span>
          </div>
          <figure className="hero-map">
            <AfricaMap />
            <figcaption>{t(lang, "Burundi, the heart of Africa. Addis Ababa, home of the African Union.", "Le Burundi, cœur de l’Afrique. Addis-Abeba, siège de l’Union africaine.")}</figcaption>
          </figure>
        </div>
      </section>

      <section className="sec sec--tight sec--ivory">
        <div className="wrap stack">
          <SectionHead size="h2 h2--md" eyebrow={t(lang, "Consular services", "Services consulaires")} title={t(lang, "How can we help?", "Comment pouvons-nous vous aider ?")} more={t(lang, "All services and fees", "Tous les services et tarifs")} moreHref="/services" />
          <div className="cols cols-5">
            {services.map((s) => (
              <Link key={s.href} className="card svc-card" href={s.href}>
                <span className="icon-circle"><Ico d={s.icon} /></span>
                <span className="h3">{s.title}</span>
                <span className="small muted">{s.body}</span>
                <span className="push small bold">{s.foot}</span>
              </Link>
            ))}
            <Link className="card card--red svc-card" href="/travel#emergency">
              <span className="icon-circle icon-circle--white"><Ico d={ICONS.warn} stroke="#B3161C" /></span>
              <span className="h3">{t(lang, "Emergency", "Urgence")}</span>
              <span className="small" style={{ color: "#6B2226" }}>{t(lang, "Help for Burundians in difficulty abroad.", "Aide aux Burundais en difficulté à l’étranger.")}</span>
              <span className="push small bold arrow">{t(lang, "Contact the Embassy", "Contacter l’Ambassade")}</span>
            </Link>
          </div>
        </div>
      </section>

      <Band />

      <section className="sec">
        <div className="wrap grid grid--center">
          <div className="span-5 stack" style={{ gap: 20 }}>
            <span className="eyebrow">Culture</span>
            <h2 className="h2">
              {lang === "fr"
                ? <>Les tambours comptent partout en Afrique. Au Burundi, ils sont <em className="ital">presque sacrés.</em></>
                : <>Drums matter across Africa. In Burundi, they are <em className="ital">almost spiritual.</em></>}
            </h2>
            <p className="lede lede--sm">
              {t(lang,
                "The Royal Drummers of Burundi have performed for more than forty years on the karyenda, amashako, ibishikiso and ikiranya drums. Dance follows the drums at celebrations and family gatherings, and elders pass on stories and legends to the young.",
                "Les Tambourinaires du Burundi jouent depuis plus de quarante ans sur les tambours karyenda, amashako, ibishikiso et ikiranya. La danse suit le tambour lors des fêtes et des réunions de famille, et les anciens transmettent contes et légendes aux plus jeunes.")}
            </p>
            <div className="row" style={{ gap: 24 }}>
              <Link className="more arrow" href="/burundi#culture">{t(lang, "Culture & history", "Culture & histoire")}</Link>
              <Link className="more arrow" href="/travel">{t(lang, "Visit Burundi", "Visiter le Burundi")}</Link>
            </div>
          </div>
          <div className="span-6 start-7 culture-grid">
            <figure className="fig" style={{ gridColumn: "span 3", gridRow: "span 2" }}><img src="/img/dancers.jpg" alt="Dancers in green and red holding woven baskets" style={{ objectPosition: "58% center" }} loading="lazy" /><figcaption className="cap-pill">{t(lang, "Welcome dance", "Danse de bienvenue")}</figcaption></figure>
            <figure className="fig" style={{ gridColumn: "span 2" }}><img src="/img/drummers.jpg" alt="Burundian drummers and a dancer with a shield" style={{ objectPosition: "38% center" }} loading="lazy" /><figcaption className="cap-pill">{t(lang, "The drum", "Le tambour")}</figcaption></figure>
            <figure className="fig" style={{ gridColumn: "span 2" }}><img src="/img/karera-falls.jpg" alt="Karera waterfalls" loading="lazy" /><figcaption className="cap-pill">Karera Falls</figcaption></figure>
          </div>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap grid grid--center">
          <figure className="span-7">
            <div className="fig" style={{ height: 540 }}><img src="/img/gavel-handover.jpg" alt="President Évariste Ndayishimiye receives the gavel of the African Union chairmanship" style={{ objectPosition: "center 30%" }} loading="lazy" /></div>
            <figcaption className="caption">{t(lang, "The chairmanship passes to Burundi at the 39th AU Summit, Addis Ababa, February 2026.", "La présidence passe au Burundi lors du 39e Sommet de l’UA, Addis-Abeba, février 2026.")}</figcaption>
          </figure>
          <div className="span-5 stack" style={{ gap: 18 }}>
            <span className="eyebrow">{t(lang, "African Union · 2026", "Union africaine · 2026")}</span>
            <h2 className="h2">{t(lang, "Burundi chairs the African Union.", "Le Burundi préside l’Union africaine.")}</h2>
            <p className="lede lede--sm">{t(lang, "President Évariste Ndayishimiye was elected Chairperson of the Union at the 39th Summit in Addis Ababa. Follow the year’s priorities, summit coverage and speeches.", "Le Président Évariste Ndayishimiye a été élu Président de l’Union lors du 39e Sommet à Addis-Abeba. Suivez les priorités de l’année, la couverture des sommets et les discours.")}</p>
            <ol className="rule-list">
              {agendas.map((a, i) => (
                <li key={a.id}>
                  <Link href={`/au-2026/priorities#${a.slug}`}>
                    <span className="row" style={{ gap: 16, alignItems: "baseline" }}><span className="num" style={{ fontSize: 15 }}>{String(i + 1).padStart(2, "0")}</span><span className="h3">{tr(a, "title", lang)}</span></span>
                    <span aria-hidden="true">→</span>
                  </Link>
                </li>
              ))}
            </ol>
            <div className="panel"><span className="eyebrow" style={{ fontSize: 14 }}>{t(lang, "AU theme of the year", "Thème de l’année de l’UA")}</span><span className="ital" style={{ fontSize: 18, lineHeight: 1.4 }}>{theme}</span></div>
            <Link className="btn btn--md" href="/au-2026" style={{ alignSelf: "flex-start" }}><span className="dot" />{t(lang, "Follow the chairmanship", "Suivre la présidence")}</Link>
          </div>
        </div>
      </section>

      <section className="sec sec--rule">
        <div className="wrap stack stack--lg">
          <div className="between" style={{ alignItems: "baseline" }}>
            <h2 className="h2">Burundi, <em className="ital">{t(lang, "measured", "en chiffres")}</em></h2>
            <Link className="more arrow" href="/burundi#geography">{t(lang, "Geography of Burundi", "Géographie du Burundi")}</Link>
          </div>
          <dl className="stats">
            <div><dt>27,834<small> km²</small></dt><dd>{t(lang, "Total area, of which 2,180 km² is water", "Superficie totale, dont 2 180 km² d’eau")}</dd></div>
            <div><dt>974<small> km</small></dt><dd>{t(lang, "Of borders with DR Congo, Rwanda and Tanzania", "De frontières avec la RD Congo, le Rwanda et la Tanzanie")}</dd></div>
            <div><dt>2,684<small> m</small></dt><dd>{t(lang, "Highest point, south-east of Mount Heha", "Point culminant, au sud-est du mont Heha")}</dd></div>
            <div><dt>772<small> m</small></dt><dd>{t(lang, "Lowest point, the shore of Lake Tanganyika", "Point le plus bas, la rive du lac Tanganyika")}</dd></div>
            <div><dt>1,200<small> km</small></dt><dd>{t(lang, "To the Indian Ocean, across the Congo–Nile divide", "Jusqu’à l’océan Indien, par la crête Congo-Nil")}</dd></div>
          </dl>
        </div>
      </section>

      <section className="sec sec--ivory" id="news">
        <div className="wrap stack stack--lg">
          <div className="between">
            <div className="stack" style={{ gap: 8 }}><span className="eyebrow">{t(lang, "Newsroom", "Actualités")}</span><h2 className="h2 h2--xl">{t(lang, "Dispatches", "Dépêches")}</h2></div>
            <div className="chips">
              <Link className="chip is-active" href="/news">{t(lang, "All", "Tout")}</Link>
              {categories.slice(0, 5).map((c) => <Link key={c.id} className="chip" href={`/news?category=${c.id}`}>{tr(c, "name", lang)}</Link>)}
            </div>
          </div>
          {featured ? (
            <div className="dispatch-grid">
              <Link className="card card--flush dispatch-lead" href={`/news/${featured.id}`}>
                <img src={media(featured.medium_url || featured.image) || "/img/au-hq.jpg"} alt="" loading="lazy" />
                <div className="card-body">
                  <span className="meta">{featured.category ? `${tr(featured.category, "name", lang)} · ` : ""}{fmtDate(featured.publish_date, lang)}</span>
                  <h3 className="h3 h3--lg" style={{ fontSize: 38 }}>{tr(featured, "title", lang)}</h3>
                  <p className="muted">{excerpt(tr(featured, "content", lang))}</p>
                </div>
              </Link>
              {rest.map((a, i) =>
                i === 0 ? (
                  <Link key={a.id} className="card card--flush card--gold dispatch-gold" href={`/news/${a.id}`}>
                    <img src={media(a.medium_url || a.image) || "/img/president-podium.jpg"} alt="" loading="lazy" />
                    <div className="card-body"><span className="meta" style={{ color: "inherit" }}>{fmtDate(a.publish_date, lang)}</span><h3 className="h3 h3--sm" style={{ fontWeight: 700 }}>{tr(a, "title", lang)}</h3></div>
                  </Link>
                ) : (
                  <Link key={a.id} className={`card ${i === 1 ? "dispatch-5" : "dispatch-4"}`} href={`/news/${a.id}`}>
                    <span className="meta">{a.category ? `${tr(a.category, "name", lang)} · ` : ""}{fmtDate(a.publish_date, lang)}</span>
                    <h3 className="h3 h3--sm">{tr(a, "title", lang)}</h3>
                  </Link>
                ),
              )}
            </div>
          ) : (
            <Empty>{t(lang, "No news published yet.", "Aucune actualité publiée pour le moment.")}</Empty>
          )}
          <div><Link className="btn btn--outline btn--md" href="/news">{t(lang, "All news", "Toutes les actualités")}</Link></div>
        </div>
      </section>

      {(liveNow || upcoming.length > 0) && (
        <section className="sec sec--dark">
          <div className="wrap grid grid--center">
            {liveNow && (
              <a className="span-7 fig fig--16x9" href={liveNow.stream_url} rel="noopener">
                <img src={media(liveNow.thumbnail) || "/img/drummers.jpg"} alt="" loading="lazy" />
                <span className="scrim" /><PlayIcon />
                <span className="tag tag--live" style={{ position: "absolute", left: 20, top: 20 }}>LIVE</span>
                <span style={{ position: "absolute", left: 20, right: 20, bottom: 20, color: "#fff", fontFamily: "var(--display)", fontSize: 26 }}>{tr(liveNow, "title", lang)}</span>
              </a>
            )}
            <div className={`${liveNow ? "span-5" : "span-12"} stack`} style={{ gap: 18 }}>
              <span className="eyebrow eyebrow--gold">{t(lang, "Coming up", "Prochainement")}</span>
              <h2 className="h2">{liveNow ? t(lang, "Live now", "En direct maintenant") : t(lang, "Next on the calendar", "Prochains événements")}</h2>
              {upcoming.length === 0 && liveNow && (
                <p className="lede lede--sm" style={{ color: "#C9D9C6" }}>{excerpt(tr(liveNow, "description", lang) || tr(liveNow, "title", lang), 40)}</p>
              )}
              <ul className="rule-list">
                {upcoming.map((e) => (
                  <li key={e.id}>
                    <Link href={`/events#event-${e.id}`}>
                      <span className="stack" style={{ gap: 4 }}><span className="sc" style={{ color: "#A7BFA9", fontSize: 14 }}>{fmtDate(e.event_date, lang, { weekday: "short", hour: "2-digit", minute: "2-digit" })}</span><span className="h3 h3--sm">{tr(e, "name", lang)}</span></span>
                      <span aria-hidden="true">→</span>
                    </Link>
                  </li>
                ))}
              </ul>
              <div className="row" style={{ gap: 12 }}>
                {liveNow && <a className="btn btn--gold btn--md" href={liveNow.stream_url} rel="noopener">{t(lang, "Watch live", "Regarder en direct")}</a>}
                <Link className={`btn btn--md ${liveNow ? "btn--ghost" : "btn--gold"}`} href="/events">{t(lang, "All events", "Tous les événements")}</Link>
              </div>
            </div>
          </div>
        </section>
      )}

      <section className="sec">
        <div className="wrap grid grid--center">
          <figure className="span-4 fig fig--arch" style={{ height: 440 }}><img src="/img/ambassador.jpg" alt="Ambassador Willy Nyamitwe at African Union headquarters" style={{ objectPosition: "50% 15%" }} loading="lazy" /></figure>
          <div className="span-7 start-6 stack" style={{ gap: 28 }}>
            <span className="eyebrow">{t(lang, "A word from the Ambassador", "Le mot de l’Ambassadeur")}</span>
            <blockquote className="quote">
              {t(lang,
                "“Our mission is to foster strong and lasting relations between Burundi and our host country, Ethiopia, and with all Member States of the African Union.”",
                "« Notre mission est de tisser des relations fortes et durables entre le Burundi et notre pays hôte, l’Éthiopie, ainsi qu’avec tous les États membres de l’Union africaine. »")}
            </blockquote>
            <div className="between" style={{ paddingTop: 22, borderTop: "1px solid var(--line)", alignItems: "center" }}>
              <span className="stack" style={{ gap: 0 }}><span className="bold" style={{ fontSize: 17 }}>Amb. Willy Nyamitwe</span><span className="muted" style={{ fontSize: 15 }}>{t(lang, "Ambassador and Permanent Representative of Burundi", "Ambassadeur et Représentant permanent du Burundi")}</span></span>
              <Link className="btn btn--outline btn--md" href="/embassy#message">{t(lang, "Read the full message", "Lire le message")}</Link>
            </div>
          </div>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap stack stack--lg">
          <div className="between">
            <div className="stack" style={{ gap: 8 }}><span className="eyebrow">{t(lang, "Tourism", "Tourisme")}</span><h2 className="h2 h2--xl">{lang === "fr" ? <>À <em className="ital">voir</em></> : <>Places to <em className="ital">see</em></>}</h2></div>
            <div className="row" style={{ gap: 24 }}><Link className="more arrow" href="/burundi#hotels">{t(lang, "Hotels in Bujumbura", "Hôtels à Bujumbura")}</Link><Link className="more arrow" href="/travel">{t(lang, "Travelling to Burundi", "Voyager au Burundi")}</Link></div>
          </div>
          <div className="places">
            {places.map(([src, title, alt, pos], i) => (
              <Link key={title} className="stack no-ul" style={{ gap: 12 }} href="/burundi#places">
                <span className="fig"><img src={src} alt={alt} style={pos ? { objectPosition: pos } : undefined} loading="lazy" /></span>
                <span className="num small">{String(i + 1).padStart(2, "0")}</span>
                <span className="h3" style={{ marginTop: -6 }}>{title}</span>
              </Link>
            ))}
          </div>
          <div className="chips">
            {["Ruvubu National Park", "Faille des Allemands", "Lac aux oiseaux", "Rusizi National Park"].map((p) => <Link key={p} className="chip" href="/burundi#places">{p}</Link>)}
          </div>
        </div>
      </section>
    </>
  );
}
