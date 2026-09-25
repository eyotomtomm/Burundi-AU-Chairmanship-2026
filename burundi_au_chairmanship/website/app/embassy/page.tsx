import type { Metadata } from "next";
import Link from "next/link";
import { api } from "@/lib/api";
import { getLang, t, tr } from "@/lib/i18n";
import type { EmbassyLocation } from "@/lib/types";
import { Crumbs, Ico, ICONS } from "@/components/ui";
import s from "./page.module.css";

export const metadata: Metadata = {
  title: "The Embassy",
  description: "The Embassy of the Republic of Burundi in Addis Ababa: jurisdiction, the Ambassador’s message, staff, hours and contact.",
};

const MAIL = "info@burundiaddis.gov.bi";
// Shown until the API's embassy-locations endpoint is deployed / when it has no Addis entry.
const ADDIS_FALLBACK = {
  address: "Bole Sub-City, Kebele 03/05, Addis Ababa",
  phones: ["+251 114 651 300", "+251 114 655 547", "+251 911 208 857"],
  email: MAIL,
  hours: null as string | null,
  maps: "https://www.google.com/maps/search/?api=1&query=Embassy+of+Burundi+Addis+Ababa",
};

export default async function Embassy() {
  const lang = await getLang();
  const missions = await api.embassies();
  const addis = missions.find((m) => /addis/i.test(m.city)) ?? null;
  const others = missions.filter((m) => m !== addis);
  const contact = addis
    ? { address: addis.address, phones: addis.phone_number ? [addis.phone_number] : ADDIS_FALLBACK.phones, email: addis.email || MAIL, hours: addis.opening_hours || null, maps: `https://www.google.com/maps?q=${addis.latitude},${addis.longitude}` }
    : ADDIS_FALLBACK;

  const mandates: Array<[string, string]> = [
    ["Ethiopia", t(lang, "Host country", "Pays hôte")],
    [t(lang, "African Union", "Union africaine"), t(lang, "Permanent Mission", "Mission permanente")],
    ["UNECA", t(lang, "Permanent Mission", "Mission permanente")],
    [t(lang, "Chad", "Tchad"), t(lang, "Accredited since May 2025", "Accrédité depuis mai 2025")],
    ["Djibouti", t(lang, "Accredited", "Accrédité")],
    [t(lang, "Eritrea", "Érythrée"), t(lang, "Accredited", "Accrédité")],
    [t(lang, "South Sudan", "Soudan du Sud"), t(lang, "Accredited", "Accrédité")],
    [t(lang, "Israel", "Israël"), t(lang, "Accredited", "Accrédité")],
  ];
  const message = [
    t(lang, "Welcome to the official website of the Permanent Mission of Burundi in Addis Ababa. We are delighted to serve as a bridge linking Burundi with Chad, Djibouti, South Sudan, Eritrea and the State of Israel, and with all diplomatic entities in Ethiopia.", "Bienvenue sur le site officiel de la Mission permanente du Burundi à Addis-Abeba. Nous sommes heureux de servir de pont entre le Burundi et le Tchad, Djibouti, le Soudan du Sud, l’Érythrée et l’État d’Israël, ainsi qu’avec toutes les entités diplomatiques en Éthiopie."),
    t(lang, "The Embassy also serves as the Permanent Mission of the Republic of Burundi to the African Union and to the United Nations Economic Commission for Africa (UNECA).", "L’Ambassade est également la Mission permanente de la République du Burundi auprès de l’Union africaine et de la Commission économique des Nations unies pour l’Afrique (CEA)."),
    t(lang, "Our mission is to foster strong and lasting relations between Burundi and our host country, Ethiopia, and with all Member States of the African Union. We promote Burundi’s interests, including economic, cultural and development cooperation, and provide support and services to our nationals abroad.", "Notre mission est de tisser des relations fortes et durables entre le Burundi et notre pays hôte, l’Éthiopie, ainsi qu’avec tous les États membres de l’Union africaine. Nous promouvons les intérêts du Burundi, y compris la coopération économique, culturelle et au développement, et apportons appui et services à nos ressortissants à l’étranger."),
    t(lang, "Here you will find information on our services, including visa and passport applications, trade and investment opportunities and cultural exchanges, along with news on Burundi’s part in international affairs, particularly at the African Union.", "Vous trouverez ici des informations sur nos services, notamment les demandes de visa et de passeport, les opportunités de commerce et d’investissement et les échanges culturels, ainsi que l’actualité du rôle du Burundi dans les affaires internationales, en particulier à l’Union africaine."),
    t(lang, "Whether you are a Burundian living in Ethiopia, Chad, Djibouti, Eritrea, South Sudan or Israel, a potential investor, a fellow diplomat or simply curious about our country, we hope this website serves you well. Thank you for your visit.", "Que vous soyez un Burundais vivant en Éthiopie, au Tchad, à Djibouti, en Érythrée, au Soudan du Sud ou en Israël, un investisseur potentiel, un collègue diplomate ou simplement curieux de notre pays, nous espérons que ce site vous sera utile. Merci de votre visite."),
  ];
  const roles = [t(lang, "First Counsellor", "Premier Conseiller"), t(lang, "Consular section", "Section consulaire"), t(lang, "African Union desk", "Bureau Union africaine")];
  const typeLabel = (ty: EmbassyLocation["type"]) =>
    ({ embassy: t(lang, "Embassies", "Ambassades"), consulate: t(lang, "Consulates", "Consulats"), office: t(lang, "Offices", "Bureaux"), event_venue: t(lang, "Venues", "Lieux") })[ty];
  const groups = ["embassy", "consulate", "office", "event_venue"]
    .map((ty) => [ty, others.filter((m) => m.type === ty)] as [EmbassyLocation["type"], EmbassyLocation[]])
    .filter(([, list]) => list.length);

  return (
    <>
      <section className="page-hero">
        <div className="wrap grid grid--center">
          <div className="span-6 stack" style={{ gap: 24 }}>
            <Crumbs lang={lang} items={[[t(lang, "The Embassy", "L’Ambassade")]]} />
            <h1 className="h1">{lang === "fr" ? <>Un pont entre le Burundi et le <em className="hl">cœur de l’Union</em></> : <>A bridge between Burundi and the <em className="hl">heart of the Union</em></>}</h1>
            <p className="lede">{t(lang, "The Embassy of the Republic of Burundi in Addis Ababa handles bilateral relations with Ethiopia, Chad, Djibouti, Eritrea, South Sudan and Israel. It is also Burundi’s Permanent Mission to the African Union and to the UN Economic Commission for Africa, and a bridge for Ethiopian investors interested in Burundi.", "L’Ambassade de la République du Burundi à Addis-Abeba gère les relations bilatérales avec l’Éthiopie, le Tchad, Djibouti, l’Érythrée, le Soudan du Sud et Israël. Elle est aussi la Mission permanente du Burundi auprès de l’Union africaine et de la Commission économique des Nations unies pour l’Afrique, et un pont pour les investisseurs éthiopiens intéressés par le Burundi.")}</p>
            <div className="row btn-row">
              <a className="btn" href="#contact">{t(lang, "Hours and contact", "Horaires et contact")}</a>
              <Link className="btn btn--outline" href="/services">{t(lang, "Consular services", "Services consulaires")}</Link>
            </div>
          </div>
          <figure className="span-5 start-8">
            <div className="fig fig--4x3"><img src="/img/handshake.jpg" alt="Two diplomats shake hands in front of the African Union and Burundi flags" style={{ objectPosition: "70% 30%" }} /></div>
            <figcaption className="caption">{t(lang, "Amb. Willy Nyamitwe at the African Union headquarters.", "L’Amb. Willy Nyamitwe au siège de l’Union africaine.")}</figcaption>
          </figure>
        </div>
      </section>

      <section id="jurisdiction" className="sec sec--ivory">
        <div className="wrap grid">
          <div className="span-4 stack" style={{ gap: 14 }}>
            <span className="eyebrow">{t(lang, "Jurisdiction", "Juridiction")}</span>
            <h2 className="h2">{lang === "fr" ? <>Une ambassade, <em className="ital">huit mandats</em></> : <>One embassy, <em className="ital">eight mandates</em></>}</h2>
            <p className="lede lede--sm">{t(lang, "From Addis Ababa, the Embassy represents Burundi in six countries and serves as its Permanent Mission to the African Union and to the UN Economic Commission for Africa.", "Depuis Addis-Abeba, l’Ambassade représente le Burundi dans six pays et sert de Mission permanente auprès de l’Union africaine et de la Commission économique des Nations unies pour l’Afrique.")}</p>
            <div className="fig fig--3x2" style={{ marginTop: 10 }}><img src="/img/au-hq.jpg" alt="The African Union headquarters in Addis Ababa" loading="lazy" /></div>
          </div>
          <ol className={`span-7 start-6 ${s.mandates}`}>
            {mandates.map(([name, role], i) => (
              <li key={name} className="card">
                <span className="num" style={{ fontSize: 15 }}>{String(i + 1).padStart(2, "0")}</span>
                <span className="h3">{name}</span>
                <span className="small muted">{role}</span>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section id="message" className="sec">
        <div className="wrap grid">
          <figure className="span-4 stack" style={{ gap: 14 }}>
            <div className="fig fig--arch" style={{ height: 480 }}><img src="/img/ambassador.jpg" alt="Ambassador Willy Nyamitwe at African Union headquarters" style={{ objectPosition: "50% 15%" }} loading="lazy" /></div>
            <figcaption className="stack" style={{ gap: 0 }}><span className="bold" style={{ fontSize: 17 }}>Amb. Willy Nyamitwe</span><span className="muted" style={{ fontSize: 15 }}>{t(lang, "Ambassador and Permanent Representative of Burundi", "Ambassadeur et Représentant permanent du Burundi")}</span></figcaption>
          </figure>
          <div className="span-7 start-6 stack" style={{ gap: 24 }}>
            <span className="eyebrow">{t(lang, "Message from the Ambassador", "Message de l’Ambassadeur")}</span>
            <blockquote className="quote">{t(lang, "“Our mission is to foster strong and lasting relations between Burundi and our host country, Ethiopia, and with all Member States of the African Union.”", "« Notre mission est de tisser des relations fortes et durables entre le Burundi et notre pays hôte, l’Éthiopie, ainsi qu’avec tous les États membres de l’Union africaine. »")}</blockquote>
            <div className="prose" style={{ fontSize: 17 }}>{message.map((p, i) => <p key={i}>{p}</p>)}</div>
          </div>
        </div>
      </section>

      <section id="team" className="sec sec--ivory">
        <div className="wrap stack">
          <figure>
            <div className="fig" style={{ height: 520 }}><img src="/img/embassy-team.jpg" alt="The Embassy team together on the staircase" style={{ objectPosition: "center 30%" }} loading="lazy" /></div>
            <figcaption className="caption">{t(lang, "The Embassy team in Addis Ababa.", "L’équipe de l’Ambassade à Addis-Abeba.")}</figcaption>
          </figure>
          <div className="grid">
            <div className="span-4 stack" style={{ gap: 6 }}>
              <span className="eyebrow">{t(lang, "Our team", "Notre équipe")}</span>
              <h2 className="h2">{t(lang, "Embassy staff", "Le personnel de l’Ambassade")}</h2>
            </div>
            <div className="span-7 start-6 stack" style={{ gap: 24 }}>
              <p className="lede lede--sm">{t(lang, "One team serving Burundians and partners in Ethiopia, Chad, Djibouti, Eritrea, South Sudan and Israel, and representing Burundi at the African Union and UNECA.", "Une équipe au service des Burundais et des partenaires en Éthiopie, au Tchad, à Djibouti, en Érythrée, au Soudan du Sud et en Israël, et qui représente le Burundi auprès de l’Union africaine et de la CEA.")}</p>
              <ul className={s.staff}>
                <li><img src="/img/ambassador.jpg" alt="" style={{ objectPosition: "50% 12%" }} loading="lazy" /><span className="stack" style={{ gap: 0 }}><b>Amb. Willy Nyamitwe</b><span className="small muted">{t(lang, "Head of Mission", "Chef de Mission")}</span></span></li>
                {roles.map((r) => (
                  <li key={r}><span className={s.avatar}><Ico d={ICONS.users} size={22} stroke="#4E5E53" /></span><span className="stack" style={{ gap: 0 }}><b>{r}</b><span className="small muted">{t(lang, "Contact via the Embassy", "Contact via l’Ambassade")}</span></span></li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </section>

      <section id="contact" className="sec">
        <div className="wrap grid">
          <div className="span-6">
            <a className={`fig ${s.map}`} href={contact.maps} rel="noopener" aria-label={t(lang, "Open in Google Maps", "Ouvrir dans Google Maps")}>
              <img src="/img/au-hq-duotone.jpg" alt="" loading="lazy" />
              <span className="cap-pill"><Ico d={ICONS.pin} size={16} /> Bole Sub-City, Kebele 03/05</span>
            </a>
          </div>
          <div className="span-5 start-8 stack" style={{ gap: 20 }}>
            <span className="eyebrow">{t(lang, "Visit us", "Nous rendre visite")}</span>
            <h2 className="h2">{t(lang, "Hours and contact", "Horaires et contact")}</h2>
            <dl className="dl">
              <dt>{t(lang, "Open", "Ouvert")}</dt><dd>{contact.hours ?? t(lang, "Monday to Friday, 7:00–16:00", "Lundi à vendredi, 7h00–16h00")}</dd>
              <dt>{t(lang, "Address", "Adresse")}</dt><dd>{contact.address}</dd>
              <dt>{t(lang, "Phone", "Téléphone")}</dt><dd>{contact.phones.map((p, i) => <span key={p}>{i > 0 && " · "}<a href={`tel:${p.replace(/\s/g, "")}`}>{p}</a></span>)}</dd>
              <dt>Email</dt><dd><a href={`mailto:${contact.email}`}>{contact.email}</a></dd>
            </dl>
            <div className="row">
              <a className="btn btn--md" href={contact.maps} rel="noopener">{t(lang, "Get directions", "Itinéraire")}</a>
              <Link className="btn btn--outline btn--md" href="/services">{t(lang, "Consular services", "Services consulaires")}</Link>
            </div>
            <Link className="card card--red" href="/travel#emergency" style={{ gap: 6 }}>
              <span className="row" style={{ gap: 10 }}><Ico d={ICONS.warn} stroke="#B3161C" size={20} /><b>{t(lang, "Emergency assistance", "Assistance d’urgence")}</b></span>
              <span className="small" style={{ color: "#6B2226" }}>{t(lang, "For Burundians in difficulty in the Embassy’s jurisdiction.", "Pour les Burundais en difficulté dans la juridiction de l’Ambassade.")}</span>
              <span className="small bold arrow">{t(lang, "Emergency numbers and SOS", "Numéros d’urgence et SOS")}</span>
            </Link>
          </div>
        </div>
      </section>

      {(
        <section id="missions" className="sec sec--ivory">
          <div className="wrap stack">
            <div className="stack" style={{ gap: 6 }}>
              <span className="eyebrow">{t(lang, "Around the world", "Dans le monde")}</span>
              <h2 className="h2">{t(lang, "Other Burundian missions", "Autres missions du Burundi")}</h2>
            </div>
            {groups.length === 0 && <p className="empty">{t(lang, "The list of Burundi’s embassies and consulates is being updated. Until then, write to info@burundiaddis.gov.bi.", "La liste des ambassades et consulats du Burundi est en cours de mise à jour. En attendant, écrivez à info@burundiaddis.gov.bi.")}</p>}
            {groups.map(([ty, list]) => (
              <div key={ty} className="stack" style={{ gap: 16 }}>
                <h3 className="eyebrow" style={{ fontSize: 18 }}>{typeLabel(ty)}</h3>
                <div className="cols cols-3">
                  {list.map((m) => (
                    <article key={m.id} className="card" style={{ border: 0, gap: 8 }}>
                      <span className="h3" style={{ fontSize: 24 }}>{tr(m, "name", lang)}</span>
                      <span className="small muted">{m.address}{m.address ? ", " : ""}{m.city}, {m.country}</span>
                      {m.opening_hours && <span className="small">{m.opening_hours}</span>}
                      <span className="small stack" style={{ gap: 2 }}>
                        {m.phone_number && <a href={`tel:${m.phone_number.replace(/\s/g, "")}`}>{m.phone_number}</a>}
                        {m.email && <a href={`mailto:${m.email}`}>{m.email}</a>}
                      </span>
                      <a className="push small bold arrow" href={`https://www.google.com/maps?q=${m.latitude},${m.longitude}`} rel="noopener">{t(lang, "Map", "Carte")}</a>
                    </article>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      <section id="write" className="sec sec--tight">
        <div className="wrap">
          <div className={s.writeBand}>
            <div className="stack" style={{ gap: 8 }}>
              <span className="eyebrow eyebrow--gold">{t(lang, "Suggestions", "Suggestions")}</span>
              <h2 className="h2 h2--md" style={{ fontSize: 40 }}>{t(lang, "Write to the Embassy", "Écrire à l’Ambassade")}</h2>
              <p style={{ fontSize: 17, color: "#C9D9C6" }}>{t(lang, "Send your suggestions and we will read every one. Please include your name, nationality and country of residence.", "Envoyez vos suggestions, nous lisons chacune d’elles. Merci d’indiquer votre nom, votre nationalité et votre pays de résidence.")}</p>
            </div>
            <div className="row" style={{ flexShrink: 0 }}>
              <a className="btn btn--gold btn--md" href={`mailto:${MAIL}?subject=${encodeURIComponent(t(lang, "Suggestion for the Embassy", "Suggestion pour l’Ambassade"))}`}>{t(lang, "Send a suggestion", "Envoyer une suggestion")}</a>
              <Link className="btn btn--ghost btn--md" href="/diaspora">{t(lang, "Diaspora registration", "Inscription diaspora")}</Link>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
