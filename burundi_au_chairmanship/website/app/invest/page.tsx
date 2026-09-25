import Link from "next/link";
import type { Metadata } from "next";
import { api, media } from "@/lib/api";
import { excerpt, fmtDate, getLang, t, tr } from "@/lib/i18n";
import { Crumbs, Empty, SectionHead } from "@/components/ui";

export const metadata: Metadata = {
  title: "Invest in Burundi",
  description: "Burundi’s financial sector at a glance, dedicated financing for young people and women, the official texts and a direct line to the Embassy in Addis Ababa.",
};

export default async function Invest() {
  const lang = await getLang();
  const [categories, resources] = await Promise.all([api.categories(), api.resources()]);
  const economy = categories.find((c) => /econom/i.test(c.name));
  const news = (await api.articles({ category: economy?.id, page_size: 4 })).results;
  const docs = resources.results.filter((r) => r.category === "official_documents");
  // ponytail: naive title match; good enough until documents get a slug
  const docFor = (words: string[]) => docs.find((d) => words.some((w) => d.title.toLowerCase().includes(w)));

  const sectors: Array<[string, string]> = [
    ["15", t(lang, "Credit institutions (the banking sector)", "Établissements de crédit (secteur bancaire)")],
    ["55", t(lang, "Microfinance institutions", "Institutions de microfinance")],
    ["15", t(lang, "Insurance companies", "Compagnies d’assurance")],
    ["3", t(lang, "Social security institutions (the pension market)", "Institutions de sécurité sociale (marché des pensions)")],
    ["3", t(lang, "Payment institutions", "Établissements de paiement")],
  ];
  const shares: Array<[string, string, string]> = [
    [t(lang, "Banking sector", "Secteur bancaire"), "82.5", "var(--ink)"],
    [t(lang, "Microfinance", "Microfinance"), "11.2", "var(--gold)"],
    [t(lang, "Insurance companies", "Assurances"), "6.4", "var(--line-2)"],
  ];
  const financing = [
    ["01 · " + t(lang, "Young people", "Jeunes"), "BIJE", t(lang, "Investment Bank for Young People in Burundi", "Banque d’investissement pour les jeunes au Burundi"), "Banque d’Investissement pour les Jeunes au Burundi", t(lang, "Finances investment projects started by young people.", "Finance les projets d’investissement portés par les jeunes."), t(lang, "Decree No. 100/145 of 23 September 2019", "Décret n° 100/145 du 23 septembre 2019")],
    ["02 · " + t(lang, "Women", "Femmes"), "BIDF", t(lang, "Investment and Development Bank for Women in Burundi", "Banque d’investissement et de développement pour les femmes au Burundi"), "Banque d’Investissement et de Développement pour les Femmes au Burundi", t(lang, "Finances investment projects started by women.", "Finance les projets d’investissement portés par les femmes."), t(lang, "Decree No. 100/072 of 8 May 2020", "Décret n° 100/072 du 8 mai 2020")],
    ["03 · " + t(lang, "Loan guarantees", "Garanties de prêt"), t(lang, "Guarantee fund", "Fonds de garantie"), t(lang, "Fund for impetus, guarantee and support", "Fonds d’impulsion, de garantie et d’accompagnement"), "Fonds d’impulsion, de garantie et d’accompagnement", t(lang, "Projects by women and young people can use its mechanisms to guarantee their investment loans.", "Les projets des femmes et des jeunes peuvent recourir à ses mécanismes pour garantir leurs prêts d’investissement."), t(lang, "Decree No. 100/038 of 18 February 2021, amending Decree No. 100/116 of 21 April 2015", "Décret n° 100/038 du 18 février 2021, modifiant le décret n° 100/116 du 21 avril 2015")],
    ["04 · " + t(lang, "Young people", "Jeunes"), "PAEEJ", t(lang, "Youth Economic Empowerment and Employment Programme", "Programme d’autonomisation économique et d’emploi des jeunes"), "Programme d’Autonomisation Économique et d’Emploi des Jeunes", t(lang, "Also offers loan guarantees to young people.", "Offre aussi des garanties de prêt aux jeunes."), t(lang, "Decree No. 100/107 of 7 April 2021", "Décret n° 100/107 du 7 avril 2021")],
  ];
  const openings = [
    [t(lang, "A guarantee fund", "Un fonds de garantie"), t(lang, "Invest in a guarantee fund that backs investors with profitable projects who lack financing, especially for investments that need long-term credit.", "Investir dans un fonds de garantie qui soutient les investisseurs porteurs de projets rentables mais sans financement, surtout pour les investissements nécessitant un crédit à long terme.")],
    [t(lang, "Credit information bureaus", "Bureaux d’information sur le crédit"), t(lang, "Invest in credit information bureaus that promote financial inclusion and reduce the risks of banks, financial institutions and microfinance institutions, to the benefit of the whole sector.", "Investir dans des bureaux d’information sur le crédit qui favorisent l’inclusion financière et réduisent les risques des banques, établissements financiers et institutions de microfinance, au bénéfice de tout le secteur.")],
    [t(lang, "Young and women-led projects", "Projets portés par les jeunes et les femmes"), t(lang, "Dedicated banks now finance projects led by young people (BIJE, 2019) and by women (BIDF, 2020).", "Des banques dédiées financent désormais les projets des jeunes (BIJE, 2019) et des femmes (BIDF, 2020).")],
  ];
  const pillars = [t(lang, "Foreign investment", "Investissement étranger"), t(lang, "Technology transfer", "Transfert de technologie"), t(lang, "Tourism", "Tourisme"), t(lang, "Industrial expansion", "Expansion industrielle"), t(lang, "Infrastructure projects", "Projets d’infrastructure")];
  const texts: Array<[string, string[]]> = [
    [t(lang, "Constitution of Burundi", "Constitution du Burundi"), ["constitution"]],
    ["Vision 2040–2060", ["vision"]],
    [t(lang, "Investment Code", "Code des investissements"), ["investment code", "investissement"]],
    [t(lang, "Mining Code", "Code minier"), ["mining", "minier"]],
    [t(lang, "Public–Private Partnership Law", "Loi sur le partenariat public-privé"), ["partnership", "ppp", "partenariat"]],
    [t(lang, "VAT Law", "Loi sur la TVA"), ["vat", "tva"]],
    [t(lang, "Banking Law", "Loi bancaire"), ["banking", "bancaire"]],
    [t(lang, "Penal Code", "Code pénal"), ["penal", "pénal"]],
  ];
  const bodies = [
    ["AU", t(lang, "African Union", "Union africaine")], ["EAC", t(lang, "East African Community", "Communauté d’Afrique de l’Est")],
    ["CEPGL", t(lang, "Economic Community of the Great Lakes Countries", "Communauté économique des pays des Grands Lacs")],
    ["ICGLR", t(lang, "International Conference on the Great Lakes Region", "Conférence internationale sur la région des Grands Lacs")],
    ["COMESA", t(lang, "Common Market for Eastern and Southern Africa", "Marché commun de l’Afrique orientale et australe")],
    ["ECCAS", t(lang, "Economic Community of Central African States", "Communauté économique des États de l’Afrique centrale")],
    ["AfCFTA", t(lang, "African Continental Free Trade Area", "Zone de libre-échange continentale africaine")],
  ];

  return (
    <>
      <section className="sec page-hero">
        <div className="wrap grid grid--center">
          <div className="span-6 stack" style={{ gap: 24 }}>
            <Crumbs lang={lang} items={[["Burundi", "/burundi"], [t(lang, "Invest", "Investir")]]} />
            <h1 className="h1">{lang === "fr" ? <>Investir au Burundi, <em className="hl">depuis Addis</em></> : <>Invest in Burundi, <em className="hl">starting in Addis</em></>}</h1>
            <p className="lede">{t(lang, "The Embassy is a bridge for Ethiopian investors who want to take up the business opportunities Burundi offers. Here you will find the financial sector at a glance, dedicated financing for young people and women, the official texts and a direct line to the Embassy.", "L’Ambassade est une passerelle pour les investisseurs éthiopiens qui veulent saisir les opportunités d’affaires qu’offre le Burundi. Vous trouverez ici le secteur financier en un coup d’œil, les financements dédiés aux jeunes et aux femmes, les textes officiels et une ligne directe avec l’Ambassade.")}</p>
            <div className="row btn-row">
              <a className="btn btn--md" href="#contact">{t(lang, "Talk to the Embassy", "Parler à l’Ambassade")}</a>
              <a className="btn btn--outline btn--md" href="#texts">{t(lang, "Official texts", "Textes officiels")}</a>
            </div>
            <span className="sc muted" style={{ fontSize: 15 }}>{t(lang, "Regional bodies", "Organisations régionales")} · AU · EAC · CEPGL · ICGLR · COMESA · ECCAS</span>
          </div>
          <figure className="span-5 start-8">
            <div className="fig fig--4x3"><img src="/img/lake-tanganyika.jpg" alt="Green hills along the shore of Lake Tanganyika" loading="lazy" /></div>
            <figcaption className="caption">{t(lang, "Lake Tanganyika. Tourism is one of the five pillars of economic diplomacy set out at Diplomatic Week 2026.", "Le lac Tanganyika. Le tourisme est l’un des cinq piliers de la diplomatie économique définis lors de la Semaine diplomatique 2026.")}</figcaption>
          </figure>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap stack stack--lg">
          <div className="grid">
            <div className="span-5 stack" style={{ gap: 12 }}>
              <span className="eyebrow">{t(lang, "The financial sector · end of December 2020", "Le secteur financier · fin décembre 2020")}</span>
              <h2 className="h2">{t(lang, "A financial system of five sectors", "Un système financier à cinq secteurs")}</h2>
            </div>
            <p className="span-6 start-7 lede lede--sm">{t(lang, "Burundi’s financial system has five sectors: credit institutions (the banking sector), microfinance institutions, insurance companies, payment institutions and social security institutions (the pension market). A securities market, a stock exchange, is being set up with its own legal framework and regulator.", "Le système financier du Burundi compte cinq secteurs : les établissements de crédit (secteur bancaire), les institutions de microfinance, les compagnies d’assurance, les établissements de paiement et les institutions de sécurité sociale (marché des pensions). Un marché des titres, une bourse, est en cours de création avec son propre cadre juridique et son régulateur.")}</p>
          </div>
          <dl className="stats">{sectors.map(([n, l]) => <div key={l}><dt>{n}</dt><dd>{l}</dd></div>)}</dl>
          <div className="panel" style={{ gap: 14 }}>
            <div className="between" style={{ alignItems: "baseline" }}><span className="eyebrow" style={{ fontSize: 14 }}>{t(lang, "Share of total assets, end 2020", "Part de l’actif total, fin 2020")}</span><span className="small muted">{t(lang, "The banking sector remains predominant.", "Le secteur bancaire reste prédominant.")}</span></div>
            <div role="img" aria-label={shares.map(([l, v]) => `${l} ${v}%`).join(", ")} style={{ display: "flex", gap: 4, height: 64 }}>
              {shares.map(([l, v, bg]) => <span key={l} style={{ flex: `${v} 0 0`, background: bg, borderRadius: 8, color: bg === "var(--ink)" ? "#fff" : "var(--ink)", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700, fontSize: 14, overflow: "hidden" }}>{Number(v) > 8 ? `${v}%` : ""}</span>)}
            </div>
            <div className="row" style={{ gap: 20 }}>{shares.map(([l, v, bg]) => <span key={l} className="row small" style={{ gap: 8 }}><span style={{ width: 12, height: 12, borderRadius: 3, background: bg }} />{l} <b>{v}%</b></span>)}</div>
          </div>
        </div>
      </section>

      <section className="sec">
        <div className="wrap stack stack--lg">
          <div className="grid">
            <div className="span-5 stack" style={{ gap: 12 }}>
              <span className="eyebrow">{t(lang, "Dedicated financing", "Financements dédiés")}</span>
              <h2 className="h2">{t(lang, "Financing for young people and women", "Financer les jeunes et les femmes")}</h2>
            </div>
            <p className="span-6 start-7 lede lede--sm">{t(lang, "In recent years, banks have been set up to finance investment projects started by young people and by women, and guarantee schemes back the investment loans granted to them.", "Ces dernières années, des banques ont été créées pour financer les projets d’investissement des jeunes et des femmes, et des mécanismes de garantie soutiennent les prêts d’investissement qui leur sont accordés.")}</p>
          </div>
          <div className="cols cols-4">
            {financing.map(([k, h, en, fr, p, decree]) => (
              <div key={h} className="card">
                <span className="meta">{k}</span>
                <span className="h3 h3--lg">{h}</span>
                <span className="bold small">{en}</span>
                {fr !== en && <span className="ital small muted">{fr}</span>}
                <span className="small">{p}</span>
                <span className="push sc small muted">{decree}</span>
              </div>
            ))}
          </div>
          <div className="card card--dark grid grid--center" style={{ padding: 40 }}>
            <div className="span-5 stack" style={{ gap: 10 }}>
              <span className="eyebrow eyebrow--gold">{t(lang, "Central bank measure · since 2020", "Mesure de la banque centrale · depuis 2020")}</span>
              <h3 className="h3 h3--lg">{t(lang, "Cheaper credit for productive investment", "Un crédit moins cher pour l’investissement productif")}</h3>
              <p style={{ color: "var(--mint-2)" }}>{t(lang, "Commercial banks refinance at the central bank at 2% a year and lend with a maximum margin of 6% a year. Lending rates, once in double digits, have fallen to a maximum of 8% for investment projects.", "Les banques commerciales se refinancent auprès de la banque centrale à 2 % l’an et prêtent avec une marge maximale de 6 % l’an. Les taux débiteurs, autrefois à deux chiffres, sont tombés à 8 % maximum pour les projets d’investissement.")}</p>
            </div>
            <div className="span-6 start-7 row" style={{ gap: 16, justifyContent: "space-between", flexWrap: "nowrap" }}>
              {[["2%", t(lang, "Refinancing rate at the central bank, per year", "Taux de refinancement à la banque centrale, par an")], ["+"], ["6%", t(lang, "Maximum bank margin, per year", "Marge bancaire maximale, par an")], ["="], ["8%", t(lang, "Maximum interest rate on investment loans", "Taux d’intérêt maximal sur les prêts d’investissement")]].map(([n, l], i) =>
                l ? <span key={i} className="stack" style={{ gap: 6, flex: 1 }}><span className="display" style={{ fontSize: 56, lineHeight: 1, color: "var(--gold)" }}>{n}</span><span className="small" style={{ color: "var(--mint-2)" }}>{l}</span></span>
                  : <span key={i} className="display" style={{ fontSize: 40, opacity: 0.6 }}>{n}</span>,
              )}
            </div>
          </div>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap stack stack--lg">
          <div className="grid">
            <div className="span-5 stack" style={{ gap: 12 }}>
              <span className="eyebrow">{t(lang, "Opportunities", "Opportunités")}</span>
              <h2 className="h2">{t(lang, "Openings in the financial sector", "Des ouvertures dans le secteur financier")}</h2>
              <p className="lede lede--sm">{t(lang, "Investment opportunities still exist in this sector, and they need to be made known to encourage investors to come and invest.", "Des opportunités d’investissement existent encore dans ce secteur, et il faut les faire connaître pour encourager les investisseurs à venir investir.")}</p>
            </div>
            <div className="span-6 start-7 stack" style={{ gap: 12 }}>
              <span className="sc muted">{t(lang, "Diplomatic Week 2026 · five pillars", "Semaine diplomatique 2026 · cinq piliers")}</span>
              <div className="chips">{pillars.map((p) => <span key={p} className="chip">{p}</span>)}</div>
            </div>
          </div>
          <div className="cols cols-3">
            {openings.map(([h, p], i) => <div key={h} className="card"><span className="num" style={{ fontSize: 28 }}>{String(i + 1).padStart(2, "0")}</span><span className="h3">{h}</span><span className="small muted">{p}</span></div>)}
          </div>
        </div>
      </section>

      <section className="sec" id="texts">
        <div className="wrap grid">
          <div className="span-4 stack" style={{ gap: 12 }}>
            <span className="eyebrow">{t(lang, "Official texts", "Textes officiels")}</span>
            <h2 className="h2">{t(lang, "Laws and codes", "Lois et codes")}</h2>
            <p className="lede lede--sm">{t(lang, "The texts that frame investment in Burundi.", "Les textes qui encadrent l’investissement au Burundi.")}</p>
            {docs.length === 0 && <p className="small muted">{t(lang, "Files are published in the media centre as they become available.", "Les fichiers sont publiés dans la médiathèque au fur et à mesure.")}</p>}
          </div>
          <ul className="span-7 start-6 rule-list rule-list--strong">
            {texts.map(([label, words]) => {
              const d = docFor(words);
              return (
                <li key={label}>
                  <a href={d ? media(d.file) : "/media#documents"} rel={d ? "noopener" : undefined}>
                    <span className="display" style={{ fontSize: 24 }}>{label}</span>
                    <span className="badge-pdf">{d ? `${d.file_type.toUpperCase()} ↓` : t(lang, "Media centre →", "Médiathèque →")}</span>
                  </a>
                </li>
              );
            })}
          </ul>
          <div className="span-12 stack" style={{ gap: 10, paddingTop: 24 }}>
            <span className="sc muted">{t(lang, "Regional integration", "Intégration régionale")}</span>
            <div className="chips">{bodies.map(([k, l]) => <span key={k} className="chip" title={l}><b style={{ marginRight: 6 }}>{k}</b> <span className="muted" style={{ fontWeight: 400 }}>{l}</span></span>)}</div>
          </div>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "Economic diplomacy", "Diplomatie économique")} title={t(lang, "Economic news", "Actualité économique")} more={t(lang, "All news", "Toutes les actualités")} moreHref={economy ? `/news?category=${economy.id}` : "/news"} />
          {news.length === 0 ? <Empty>{t(lang, "No economic news published yet.", "Aucune actualité économique pour le moment.")}</Empty> : (
            <div className="cols cols-4">
              {news.map((a) => (
                <Link key={a.id} className="card card--flush news-card" href={`/news/${a.id}`}>
                  <img src={media(a.medium_url || a.image) || "/img/au-hq.jpg"} alt="" loading="lazy" />
                  <div className="card-body" style={{ padding: 22 }}>
                    <span className="meta">{a.category ? `${tr(a.category, "name", lang)} · ` : ""}{fmtDate(a.publish_date, lang)}</span>
                    <span className="h3 h3--sm">{tr(a, "title", lang)}</span>
                    <span className="small muted">{excerpt(tr(a, "content", lang), 22)}</span>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </div>
      </section>

      <section className="sec" id="contact">
        <div className="wrap grid">
          <div className="span-5 stack">
            <span className="eyebrow">{t(lang, "Investor enquiries", "Demandes des investisseurs")}</span>
            <h2 className="h2">{t(lang, "Talk to the Embassy", "Parler à l’Ambassade")}</h2>
            <p className="lede lede--sm">{t(lang, "Tell us about your company and the sector you are looking at in Burundi. The Embassy will reply by email or phone.", "Parlez-nous de votre entreprise et du secteur qui vous intéresse au Burundi. L’Ambassade vous répondra par courriel ou par téléphone.")}</p>
            <dl className="dl">
              <dt>{t(lang, "Address", "Adresse")}</dt><dd>Bole Sub-City, Kebele 03/05, Addis Ababa</dd>
              <dt>{t(lang, "Phone", "Téléphone")}</dt><dd>+251 114 651 300 · +251 114 655 547 · +251 911 208 857</dd>
              <dt>Email</dt><dd><a className="bold" href="mailto:info@burundiaddis.gov.bi">info@burundiaddis.gov.bi</a></dd>
              <dt>{t(lang, "Open", "Horaires")}</dt><dd>{t(lang, "Monday to Friday, 7:00–16:00", "Lundi à vendredi, 7h00–16h00")}</dd>
            </dl>
            <span className="sc muted">{t(lang, "Useful links", "Liens utiles")}</span>
            <div className="chips">
              {[["https://investburundi.bi/", "investburundi.bi"], ["https://brb.bi/", "brb.bi"], ["https://obr.bi/index.php/en/", "obr.bi"]].map(([href, l]) => <a key={href} className="chip" href={href} rel="noopener">{l} ↗</a>)}
            </div>
          </div>
          <div className="span-6 start-7 card card--dark" style={{ padding: 40, gap: 20 }}>
            <span className="eyebrow eyebrow--gold">{t(lang, "Send an enquiry", "Envoyer une demande")}</span>
            <p style={{ color: "var(--mint-2)" }}>{t(lang, "Include your name, company, country, the sector you are considering and how to reach you.", "Indiquez votre nom, votre entreprise, votre pays, le secteur envisagé et vos coordonnées.")}</p>
            <div className="row btn-row">
              <a className="btn btn--gold btn--md" href={`mailto:info@burundiaddis.gov.bi?subject=${encodeURIComponent(t(lang, "Investor enquiry", "Demande d’investisseur"))}`}>{t(lang, "Email the Embassy", "Écrire à l’Ambassade")}</a>
              <a className="btn btn--ghost btn--md" href="tel:+251114651300">+251 114 651 300</a>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
