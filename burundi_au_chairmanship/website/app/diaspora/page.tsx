import Link from "next/link";
import type { Metadata } from "next";
import { api } from "@/lib/api";
import { getLang, t, tr } from "@/lib/i18n";
import { Crumbs, Empty, SectionHead } from "@/components/ui";

export const metadata: Metadata = {
  title: "Diaspora",
  description: "Register in the Burundian Diaspora database so the Embassy in Addis Ababa can reach, inform and assist you.",
};

export default async function Diaspora() {
  const lang = await getLang();
  const [missions, social] = await Promise.all([api.embassies(), api.social()]);
  const missionsSorted = [...missions]
    .filter((m) => m.type === "embassy" || m.type === "consulate")
    .sort((a, b) => a.country.localeCompare(b.country) || a.name.localeCompare(b.name));

  const why = [
    [t(lang, "Consular help and emergencies", "Aide consulaire et urgences"), t(lang, "If you lose a document, face an emergency or need consular help, the Embassy already has your details and knows how to reach you.", "Si vous perdez un document, faites face à une urgence ou avez besoin d’aide consulaire, l’Ambassade a déjà vos coordonnées et sait comment vous joindre.")],
    [t(lang, "Elections and official notices", "Élections et avis officiels"), t(lang, "Receive the official notices meant for Burundians abroad, such as the call to register for the 2025 elections.", "Recevez les avis officiels destinés aux Burundais de l’étranger, comme l’appel à s’inscrire pour les élections de 2025.")],
    [t(lang, "News and events for the community", "Actualités et événements de la communauté"), t(lang, "Hear about Embassy news and community events in Ethiopia, Chad, Djibouti, Eritrea, South Sudan and Israel.", "Suivez les nouvelles de l’Ambassade et les événements communautaires en Éthiopie, au Tchad, à Djibouti, en Érythrée, au Soudan du Sud et en Israël.")],
    [t(lang, "Skills and investment for Burundi", "Compétences et investissement pour le Burundi"), t(lang, "Your field of work and education help connect diaspora skills and investment with Burundi, an aim of the National Diaspora Policy.", "Votre domaine d’activité et votre formation aident à relier les compétences et l’investissement de la diaspora au Burundi, un objectif de la Politique nationale de la diaspora.")],
  ];

  const fields: Array<[string, string[]]> = [
    [t(lang, "Identity", "Identité"), [t(lang, "Title", "Civilité"), t(lang, "Last name", "Nom"), t(lang, "First name", "Prénom"), "Email"]],
    [t(lang, "Origin in Burundi", "Origine au Burundi"), ["Province", "Commune", "Zone", t(lang, "Colline / Quartier", "Colline / Quartier")]],
    [t(lang, "Residence", "Résidence"), [t(lang, "Country of residence", "Pays de résidence"), t(lang, "City of residence", "Ville de résidence")]],
    [t(lang, "Profile", "Profil"), [t(lang, "Field of work", "Domaine d’activité"), t(lang, "Education level", "Niveau d’études")]],
    [t(lang, "Documents", "Documents"), [t(lang, "Passport copy (PDF, JPG or PNG)", "Copie du passeport (PDF, JPG ou PNG)"), t(lang, "Passport photo (JPG or PNG)", "Photo d’identité (JPG ou PNG)")]],
  ];

  const chapters = [
    [t(lang, "Context", "Contexte")],
    [t(lang, "The Government of the Republic of Burundi and its diaspora: the current situation", "Le Gouvernement de la République du Burundi et sa diaspora : état des lieux")],
    [t(lang, "Rationale for the diaspora policy", "Justification de la politique de la diaspora")],
    [t(lang, "Strategic axes and objectives of the National Diaspora Policy", "Axes stratégiques et objectifs de la Politique nationale de la diaspora")],
    [t(lang, "Actions to achieve the objectives", "Actions pour atteindre les objectifs")],
  ];
  const covers = [
    [t(lang, "Dialogue and trust", "Dialogue et confiance"), t(lang, "Building dialogue and trust between the Government and the diaspora.", "Construire le dialogue et la confiance entre le Gouvernement et la diaspora.")],
    [t(lang, "Development", "Développement"), t(lang, "Putting diaspora remittances, skills and expertise to work for national development.", "Mettre les transferts, compétences et expertises de la diaspora au service du développement national.")],
    [t(lang, "Rights and communication", "Droits et communication"), t(lang, "Protecting the rights of the diaspora and the ways of communicating with it.", "Protéger les droits de la diaspora et les moyens de communiquer avec elle.")],
  ];

  const services = [
    ["/services#passport", t(lang, "Travel document · CGM", "Document de voyage · CGM"), t(lang, "Passport", "Passeport"), t(lang, "Ordinary, service and diplomatic passports.", "Passeports ordinaire, de service et diplomatique."), t(lang, "Ordinary 235,000 FBU", "Ordinaire 235 000 FBU")],
    ["/services#laissez-passer", t(lang, "Travel document · CGM", "Document de voyage · CGM"), "Laissez-passer", t(lang, "For travel to other EAC countries, including South Sudan.", "Pour voyager dans les autres pays de l’EAC, dont le Soudan du Sud."), t(lang, "30,000 FBU · 1 year", "30 000 FBU · 1 an")],
    ["/services#other", t(lang, "Consular service", "Service consulaire"), t(lang, "Civil status & administrative acts", "État civil et actes administratifs"), t(lang, "Civil marriage, administrative acts and legalisation.", "Mariage civil, actes administratifs et légalisation."), t(lang, "Consular desk", "Guichet consulaire")],
    ["/services#other", t(lang, "Consular service", "Service consulaire"), t(lang, "Nationality", "Nationalité"), t(lang, "Nationality applications.", "Demandes de nationalité."), t(lang, "Consular desk", "Guichet consulaire")],
    ["/travel#emergency", t(lang, "Help in an emergency", "Aide en cas d’urgence"), t(lang, "Emergency assistance", "Assistance d’urgence"), t(lang, "The Embassy’s emergency line and emergency numbers in Burundi.", "La ligne d’urgence de l’Ambassade et les numéros d’urgence au Burundi."), t(lang, "Numbers to call", "Numéros à appeler")],
    ["/news", t(lang, "Notice · 21 October 2024", "Avis · 21 octobre 2024"), "Itangazo rihamagarira Abarundi kwiyandikisha ku matora y’2025", t(lang, "Notice calling on Burundians to register for the 2025 elections (in Kirundi).", "Avis appelant les Burundais à s’inscrire pour les élections de 2025 (en kirundi)."), t(lang, "Read", "Lire")],
  ];

  const tools = [
    ["/events", t(lang, "Events", "Événements"), t(lang, "Embassy and community events", "Événements de l’Ambassade et de la communauté")],
    ["/news", t(lang, "Newsroom", "Actualités"), t(lang, "Dispatches from the Embassy and the AU chairmanship", "Dépêches de l’Ambassade et de la présidence de l’UA")],
    ["/travel#phrasebook", t(lang, "Kirundi phrasebook", "Lexique kirundi"), t(lang, "More than 600 phrases in Kirundi, English and French, in the B4Africa app", "Plus de 600 phrases en kirundi, anglais et français, dans l’app B4Africa")],
    ["/travel#emergency", t(lang, "SOS in the app", "SOS dans l’app"), t(lang, "Hold 3 seconds to call the emergency line", "Maintenez 3 secondes pour appeler la ligne d’urgence")],
  ];

  return (
    <>
      <section className="sec page-hero">
        <div className="wrap grid grid--center">
          <div className="span-6 stack" style={{ gap: 24 }}>
            <Crumbs lang={lang} items={[["Diaspora"]]} />
            <h1 className="h1">
              {lang === "fr" ? <>Où que vous viviez, vous faites <em className="hl">partie du Burundi</em></> : <>Wherever you live, you are <em className="hl">part of Burundi</em></>}
            </h1>
            <p className="lede">{t(lang, "Burundians in Ethiopia, Chad, Djibouti, Eritrea, South Sudan and Israel: register in the Burundian Diaspora database, so the Embassy can reach you, keep you informed and assist you when you need it.", "Burundais d’Éthiopie, du Tchad, de Djibouti, d’Érythrée, du Soudan du Sud et d’Israël : inscrivez-vous dans la base de données de la diaspora burundaise, pour que l’Ambassade puisse vous joindre, vous informer et vous assister quand vous en avez besoin.")}</p>
            <div className="row btn-row">
              <a className="btn btn--md" href="#register">{t(lang, "Register now", "S’inscrire")}</a>
              <a className="btn btn--outline btn--md" href="#policy">{t(lang, "The National Diaspora Policy", "La Politique nationale de la diaspora")}</a>
            </div>
            <div className="stack" style={{ gap: 4 }}>
              <span className="display" style={{ fontSize: 56 }}><span className="sc" style={{ fontSize: 18, color: "var(--ink-2)" }}>{t(lang, "about", "environ")} </span>365,000</span>
              <span className="small muted">{t(lang, "Burundians in the diaspora: the estimate given in the National Diaspora Policy, adopted in 2015.", "Burundais dans la diaspora : l’estimation donnée par la Politique nationale de la diaspora, adoptée en 2015.")}</span>
            </div>
          </div>
          <figure className="span-5 start-8 stack" style={{ gap: 14 }}>
            <div className="fig fig--4x3"><img src="/img/embassy-team.jpg" alt="The Embassy team together on the staircase" loading="lazy" /></div>
            <figcaption className="caption" style={{ marginTop: 0 }}>{t(lang, "The Embassy team in Addis Ababa.", "L’équipe de l’Ambassade à Addis-Abeba.")}</figcaption>
          </figure>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "Why register", "Pourquoi s’inscrire")} title={t(lang, "Stay within reach of your Embassy", "Restez à portée de votre Ambassade")} more={t(lang, "Go to the form ↓", "Aller au formulaire ↓")} moreHref="#register" />
          <p className="lede lede--sm">{t(lang, "The Embassy serves Burundians in six countries. The diaspora register is how it knows where you are.", "L’Ambassade sert les Burundais de six pays. Le registre de la diaspora est le moyen de savoir où vous êtes.")}</p>
          <div className="cols cols-4">
            {why.map(([h, p], i) => (
              <div key={h} className="card">
                <span className="num" style={{ fontSize: 28 }}>{String(i + 1).padStart(2, "0")}</span>
                <h3 className="h3">{h}</h3>
                <p className="muted small">{p}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="sec" id="register">
        <div className="wrap grid">
          <div className="span-7 stack">
            <div className="stack" style={{ gap: 6 }}>
              <span className="eyebrow">{t(lang, "Diaspora registration", "Inscription de la diaspora")}</span>
              <h2 className="h2">{t(lang, "Join the diaspora database", "Rejoignez la base de données de la diaspora")}</h2>
              <p className="lede lede--sm">{t(lang, "Registration is done in the B4Africa app or by email with the consular section. Online registration on this site is coming.", "L’inscription se fait dans l’app B4Africa ou par courriel auprès de la section consulaire. L’inscription en ligne sur ce site arrive bientôt.")}</p>
            </div>
            <div className="card card--ivory" style={{ gap: 24 }}>
              <span className="sc muted">{t(lang, "What you will be asked", "Ce qui vous sera demandé")}</span>
              <div className="cols cols-2" style={{ gap: 24 }}>
                {fields.map(([group, items], i) => (
                  <div key={group} className="stack" style={{ gap: 8 }}>
                    <span className="row" style={{ gap: 10 }}><span className="num">{String(i + 1).padStart(2, "0")}</span><b>{group}</b></span>
                    <ul className="stack small muted" style={{ gap: 4 }}>{items.map((f) => <li key={f}>{f}</li>)}</ul>
                  </div>
                ))}
              </div>
              <p className="form-note">{t(lang, "The Embassy keeps your details and documents in the Burundian Diaspora database and uses them only to contact and assist you.", "L’Ambassade conserve vos coordonnées et documents dans la base de données de la diaspora burundaise et ne les utilise que pour vous contacter et vous assister.")}</p>
              <div className="row btn-row">
                <a className="btn btn--md" href="/app">{t(lang, "Register in the B4Africa app", "S’inscrire dans l’app B4Africa")}</a>
                <a className="btn btn--outline btn--md" href="mailto:info@burundiaddis.gov.bi?subject=Diaspora%20registration">{t(lang, "Email the consular section", "Écrire à la section consulaire")}</a>
              </div>
            </div>
          </div>
          <aside className="span-4 start-9 stack">
            <div className="card card--dark">
              <span className="eyebrow eyebrow--gold">{t(lang, "What happens next", "Et ensuite")}</span>
              <ol className="stack" style={{ gap: 14 }}>
                {[
                  [t(lang, "Your file is checked", "Votre dossier est vérifié"), t(lang, "The consular section reviews each registration.", "La section consulaire examine chaque inscription.")],
                  [t(lang, "You receive confirmation", "Vous recevez une confirmation"), t(lang, "By email, phone or in the B4Africa app.", "Par courriel, téléphone ou dans l’app B4Africa.")],
                  [t(lang, "Keep it up to date", "Tenez-le à jour"), t(lang, "Tell the Embassy after a move or a new passport.", "Prévenez l’Ambassade après un déménagement ou un nouveau passeport.")],
                ].map(([h, p], i) => (
                  <li key={h} className="row" style={{ gap: 14, alignItems: "flex-start", flexWrap: "nowrap" }}>
                    <span className="sc" style={{ color: "var(--gold)", fontSize: 22, lineHeight: 1.2 }}>{i + 1}</span>
                    <span className="stack" style={{ gap: 2 }}><b>{h}</b><span className="small" style={{ color: "var(--mint-2)" }}>{p}</span></span>
                  </li>
                ))}
              </ol>
            </div>
            <div className="card">
              <span className="eyebrow">{t(lang, "Questions about the form?", "Des questions ?")}</span>
              <a className="bold" href="tel:+251114651300">+251 114 651 300</a>
              <a className="bold" href="mailto:info@burundiaddis.gov.bi">info@burundiaddis.gov.bi</a>
              <span className="small muted">{t(lang, "Monday to Friday, 7:00–16:00", "Lundi à vendredi, 7h00–16h00")}</span>
            </div>
            <figure><div className="fig fig--4x3"><img src="/img/dancers.jpg" alt="Dancers in green and red holding woven baskets" loading="lazy" /></div><figcaption className="caption">{t(lang, "Burundian dancers.", "Danseuses burundaises.")}</figcaption></figure>
          </aside>
        </div>
      </section>

      <section className="sec sec--ivory" id="policy">
        <div className="wrap grid">
          <div className="span-4">
            <div className="card card--dark" style={{ aspectRatio: "3 / 4", justifyContent: "space-between" }}>
              <span className="sc" style={{ color: "var(--gold)" }}>République du Burundi</span>
              <span className="display" style={{ fontSize: 26, lineHeight: 1.2 }}>POLITIQUE NATIONALE DE LA DIASPORA DE LA RÉPUBLIQUE DU BURUNDI</span>
              <span className="stack small" style={{ gap: 4, color: "var(--mint-2)" }}>
                <span>{t(lang, "Adopted by the Council of Ministers", "Adoptée par le Conseil des ministres")}</span>
                <b style={{ color: "#fff" }}>21 {t(lang, "January", "janvier")} 2015</b>
                <span>{t(lang, "French · PDF · about 48 pages", "Français · PDF · environ 48 pages")}</span>
              </span>
            </div>
            <a className="btn btn--md" style={{ marginTop: 16, width: "100%" }} href="https://www.ambabuaddisabeba.mae.gov.bi/wp-content/uploads/2024/04/Politique-Nationale-de-la-Diaspora.pdf" rel="noopener">{t(lang, "Download the policy (PDF, French)", "Télécharger la politique (PDF)")}</a>
          </div>
          <div className="span-7 start-6 stack">
            <div className="stack" style={{ gap: 6 }}>
              <span className="eyebrow">{t(lang, "National Diaspora Policy", "Politique nationale de la diaspora")}</span>
              <h2 className="h2">{t(lang, "The policy behind our work with the diaspora", "La politique qui guide notre travail avec la diaspora")}</h2>
            </div>
            <p className="lede lede--sm">{t(lang, "Adopted by the Council of Ministers on 21 January 2015, the National Diaspora Policy sets out how the Government of Burundi works with its diaspora, which it estimates at about 365,000 people.", "Adoptée par le Conseil des ministres le 21 janvier 2015, la Politique nationale de la diaspora définit la manière dont le Gouvernement du Burundi travaille avec sa diaspora, qu’il estime à environ 365 000 personnes.")}</p>
            <span className="sc muted">{t(lang, "Inside the document", "Dans le document")}</span>
            <ol className="rule-list">
              {chapters.map(([c], i) => <li key={c}><div><span className="sc" style={{ color: "var(--gold-ink)", minWidth: 96 }}>{t(lang, "Chapter", "Chapitre")} {i + 1}</span><span style={{ flex: 1 }}>{c}</span></div></li>)}
            </ol>
            <p className="small muted">{t(lang, "Also in the document: preliminary note, acronyms, executive summary, introduction, conclusion and annexes.", "Également dans le document : note préliminaire, sigles, résumé exécutif, introduction, conclusion et annexes.")}</p>
            <span className="sc muted">{t(lang, "What the policy covers", "Ce que couvre la politique")}</span>
            <div className="cols cols-3">
              {covers.map(([h, p], i) => <div key={h} className="card"><span className="num">{String(i + 1).padStart(2, "0")}</span><b>{h}</b><span className="small muted">{p}</span></div>)}
            </div>
          </div>
        </div>
      </section>

      <section className="sec">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "For Burundians abroad", "Pour les Burundais de l’étranger")} title={t(lang, "Services and notices", "Services et avis")} more={t(lang, "All consular services", "Tous les services consulaires")} moreHref="/services" />
          <p className="lede lede--sm">{t(lang, "Passports and travel documents are issued by the Commissariat Général des Migrations (CGM). Fees and the documents to bring are on the consular services page.", "Les passeports et documents de voyage sont délivrés par le Commissariat Général des Migrations (CGM). Les frais et pièces à fournir sont sur la page des services consulaires.")}</p>
          <div className="cols cols-3">
            {services.map(([href, kicker, h, p, foot]) => (
              <Link key={h} className="card" href={href}>
                <span className="meta">{kicker}</span>
                <span className="h3">{h}</span>
                <span className="small muted">{p}</span>
                <span className="push small bold arrow">{foot}</span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap stack stack--lg">
          <SectionHead eyebrow={t(lang, "Community & home", "Communauté et pays")} title={t(lang, "Close to home, wherever you are", "Proche du pays, où que vous soyez")} />
          <div className="grid">
            <div className="span-5 stack">
              <span className="sc muted">01 · {t(lang, "Invest at home", "Investir au pays")}</span>
              <h3 className="h3 h3--lg">{t(lang, "Build something in Burundi", "Construire quelque chose au Burundi")}</h3>
              <p className="muted">{t(lang, "Burundi has set up two banks that finance investment projects started by young people and by women.", "Le Burundi a créé deux banques qui financent les projets d’investissement des jeunes et des femmes.")}</p>
              <ul className="rule-list">
                <li><div><span className="stack" style={{ gap: 2 }}><b className="display" style={{ fontSize: 24 }}>BIJE</b><span className="small">Banque d’Investissement pour les Jeunes au Burundi</span></span><span className="small muted">{t(lang, "Youth investment bank · 2019", "Banque d’investissement des jeunes · 2019")}</span></div></li>
                <li><div><span className="stack" style={{ gap: 2 }}><b className="display" style={{ fontSize: 24 }}>BIDF</b><span className="small">Banque d’Investissement et de Développement pour les Femmes au Burundi</span></span><span className="small muted">{t(lang, "Women’s investment bank · 2020", "Banque d’investissement des femmes · 2020")}</span></div></li>
              </ul>
              <Link className="btn btn--outline btn--md" href="/invest" style={{ alignSelf: "flex-start" }}>{t(lang, "Invest in Burundi", "Investir au Burundi")}</Link>
            </div>
            <div className="span-6 start-7 stack">
              <span className="sc muted">02 · {t(lang, "Stay close", "Rester proche")}</span>
              <h3 className="h3 h3--lg">{t(lang, "Keep up with home", "Garder le lien avec le pays")}</h3>
              <p className="muted">{t(lang, "Events, news from the Embassy and the chairmanship, and a few useful tools from the B4Africa app.", "Événements, nouvelles de l’Ambassade et de la présidence, et quelques outils utiles de l’app B4Africa.")}</p>
              <ul className="rule-list">
                {tools.map(([href, h, p]) => <li key={h}><Link href={href}><span className="stack" style={{ gap: 2 }}><b>{h}</b><span className="small muted">{p}</span></span><span aria-hidden="true">→</span></Link></li>)}
              </ul>
              <div className="chips">{social.map((s) => <a key={s.id} className="chip" href={s.url} rel="noopener">{tr(s, "display_name", lang)}{s.handle ? ` · ${s.handle}` : ""}</a>)}</div>
            </div>
          </div>

          <div className="stack" id="missions">
            <SectionHead size="h2 h2--md" eyebrow={t(lang, "Burundian missions", "Missions burundaises")} title={t(lang, "Your nearest Embassy or Consulate", "Votre Ambassade ou Consulat le plus proche")} />
            {missionsSorted.length === 0 ? <Empty>{t(lang, "The list of missions will appear here.", "La liste des missions apparaîtra ici.")}</Empty> : (
              <div className="cols cols-3">
                {missionsSorted.map((m) => (
                  <div key={m.id} className="card">
                    <span className="meta">{m.type === "consulate" ? t(lang, "Consulate", "Consulat") : t(lang, "Embassy", "Ambassade")} · {m.country}</span>
                    <span className="h3 h3--sm">{tr(m, "name", lang)}</span>
                    <span className="small muted">{m.address}{m.address && m.city ? ", " : ""}{m.city}</span>
                    {m.phone_number && <a className="small bold" href={`tel:${m.phone_number.replace(/\s+/g, "")}`}>{m.phone_number}</a>}
                    {m.email && <a className="small bold" href={`mailto:${m.email}`}>{m.email}</a>}
                    {m.opening_hours && <span className="small muted">{m.opening_hours}</span>}
                  </div>
                ))}
              </div>
            )}
          </div>
          <figure><div className="fig fig--3x2"><img src="/img/handshake.jpg" alt="Two diplomats shake hands in front of the African Union and Burundi flags" loading="lazy" /></div></figure>
        </div>
      </section>
    </>
  );
}
