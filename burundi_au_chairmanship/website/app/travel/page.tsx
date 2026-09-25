import type { Metadata } from "next";
import Link from "next/link";
import { api } from "@/lib/api";
import { getLang, t, tr } from "@/lib/i18n";
import type { EmergencyContact } from "@/lib/types";
import { Crumbs, Ico, ICONS, SectionHead } from "@/components/ui";

export const metadata: Metadata = {
  title: "Travel & emergency",
  description: "Visas, practical facts, a few words of Kirundi and the numbers to call if something goes wrong in Burundi.",
};

const CATEGORY_ORDER: EmergencyContact["category"][] = ["police", "fire", "medical", "support", "other"];

function contactHref(c: EmergencyContact) {
  const v = c.contact_value.trim();
  switch (c.action_type) {
    case "call": return `tel:${v.replace(/[^\d+]/g, "")}`;
    case "sms": return `sms:${v.replace(/[^\d+]/g, "")}`;
    case "whatsapp": return /^https?:/.test(v) ? v : `https://wa.me/${v.replace(/\D/g, "")}`;
    case "email": return `mailto:${v}`;
    default: return v;
  }
}

export default async function Travel() {
  const lang = await getLang();
  const [contacts, missions] = await Promise.all([api.emergency(), api.embassies()]);
  const groups = CATEGORY_ORDER
    .map((cat) => ({ cat, items: contacts.filter((c) => c.category === cat && c.action_type !== "route").sort((a, b) => a.order - b.order) }))
    .filter((g) => g.items.length);
  const catLabel: Record<EmergencyContact["category"], [string, string]> = {
    police: ["Police", "Police"], fire: ["Fire", "Pompiers"], medical: ["Medical", "Médical"], support: ["Support", "Assistance"], other: ["Other", "Autres"],
  };

  const checklist: Array<[string, string, string, string, string?]> = [
    ["Visa", "Visa", "Check which visa applies to you. The visa types, their fees and validity are listed on the consular services page.", "Vérifiez quel visa vous concerne. Les types de visa, leurs frais et leur validité figurent sur la page des services consulaires.", "/services#visa"],
    ["Passport validity", "Validité du passeport", "Travel with a passport valid well beyond your stay. Confirm the exact requirement with the Embassy before you book.", "Voyagez avec un passeport valable bien au-delà de votre séjour. Confirmez l’exigence exacte auprès de l’Ambassade avant de réserver."],
    ["Health requirements", "Santé", "Ask the Embassy which vaccinations and health documents are required on entry.", "Renseignez-vous auprès de l’Ambassade sur les vaccinations et documents de santé exigés à l’entrée."],
    ["Travel insurance & flights", "Assurance & vols", "Take out travel insurance, and check the direct flights between Addis Ababa and Bujumbura.", "Souscrivez une assurance voyage et vérifiez les vols directs entre Addis-Abeba et Bujumbura."],
  ];
  const phrases: Array<[string, string, string]> = [
    ["Hello / Peace", "Amahoro", "Bonjour / Paix"],
    ["Good morning", "Bwakeye", "Bonjour (matin)"],
    ["Thank you", "Urakoze", "Merci"],
    ["Please", "Ndagusavye", "S’il vous plaît"],
    ["Excuse me / I am sorry", "Mbabarira", "Excusez-moi / Pardon"],
    ["Welcome to Burundi", "Ikaze mu Burundi", "Bienvenue au Burundi"],
    ["Where is the embassy?", "Ni hehe ambasade?", "Où est l’ambassade ?"],
    ["I need help", "Ndakeneye ubufasha", "J’ai besoin d’aide"],
  ];
  const typeLabel = (ty: string) => ({ embassy: t(lang, "Embassy", "Ambassade"), consulate: t(lang, "Consulate", "Consulat"), office: t(lang, "Office", "Bureau"), event_venue: t(lang, "Venue", "Lieu") }[ty] ?? ty);

  return (
    <>
      <section className="page-hero">
        <div className="wrap stack stack--lg" style={{ gap: 64 }}>
          <div className="grid grid--center">
            <div className="span-6 stack" style={{ gap: 24 }}>
              <Crumbs lang={lang} items={[["Burundi", "/burundi"], [t(lang, "Travel", "Voyage")]]} />
              <h1 className="h1">{lang === "fr" ? <>Préparez votre voyage au <em className="hl">cœur de l’Afrique</em></> : <>Plan your trip to the <em className="hl">heart of Africa</em></>}</h1>
              <p className="lede">{t(lang, "Visas, practical facts, a few words of Kirundi and the numbers to call if something goes wrong: what to know before you travel to Burundi.", "Visas, repères pratiques, quelques mots de kirundi et les numéros à appeler en cas de problème : ce qu’il faut savoir avant de partir au Burundi.")}</p>
              <div className="row btn-row">
                <Link className="btn btn--md" href="/services#visa">{t(lang, "Visa types and fees", "Types de visa et frais")}<Ico d={ICONS.arrow} size={18} stroke="currentColor" /></Link>
                <a className="btn btn--outline btn--md" href="#emergency"><span className="dot dot--red" />{t(lang, "Emergency numbers", "Numéros d’urgence")}</a>
              </div>
            </div>
            <figure className="span-5 start-8">
              <div className="fig" style={{ height: 500 }}><img src="/img/lake-tanganyika.jpg" alt="Green hills above Lake Tanganyika" style={{ objectPosition: "30% center" }} /></div>
              <figcaption className="caption" style={{ fontSize: 15 }}>{t(lang, "Green hills above Lake Tanganyika", "Collines vertes au-dessus du lac Tanganyika")}</figcaption>
            </figure>
          </div>
          <dl className="stats" style={{ gridTemplateColumns: "repeat(4, minmax(0, 1fr))", borderTop: "2px solid var(--ink)", paddingTop: 24 }}>
            <div><dt className="eyebrow" style={{ fontSize: 15, fontFamily: "var(--sc)" }}>{t(lang, "Currency", "Monnaie")}</dt><dd className="display" style={{ fontSize: 26, color: "var(--ink)" }}>{t(lang, "Burundian franc (BIF)", "Franc burundais (BIF)")}</dd></div>
            <div><dt className="eyebrow" style={{ fontSize: 15, fontFamily: "var(--sc)" }}>{t(lang, "Time zone", "Fuseau horaire")}</dt><dd className="display" style={{ fontSize: 26, color: "var(--ink)" }}>Burundi UTC+2</dd><dd>Addis Ababa UTC+3</dd></div>
            <div><dt className="eyebrow" style={{ fontSize: 15, fontFamily: "var(--sc)" }}>{t(lang, "Languages", "Langues")}</dt><dd className="display" style={{ fontSize: 26, color: "var(--ink)" }}>{t(lang, "Kirundi, French, English", "Kirundi, français, anglais")}</dd></div>
            <div><dt className="eyebrow" style={{ fontSize: 15, fontFamily: "var(--sc)" }}>{t(lang, "Capital", "Capitale")}</dt><dd className="display" style={{ fontSize: 26, color: "var(--ink)" }}>Gitega ({t(lang, "political", "politique")})</dd><dd>Bujumbura ({t(lang, "economic", "économique")})</dd></div>
          </dl>
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap grid">
          <div className="span-4 stack" style={{ gap: 18 }}>
            <span className="eyebrow">{t(lang, "Before you go", "Avant de partir")}</span>
            <h2 className="h2 h2--md">{t(lang, "Your checklist for Burundi", "Votre liste pour le Burundi")}</h2>
            <p className="lede lede--sm">{t(lang, "Four things to check before you fly. Start with the visa.", "Quatre points à vérifier avant le départ. Commencez par le visa.")}</p>
            <div className="panel" style={{ marginTop: 10, padding: "22px 24px" }}>
              <span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "Embassy service hours", "Horaires de l’Ambassade")}</span>
              <span className="display" style={{ fontSize: 24 }}>{t(lang, "Monday to Friday, 7:00–16:00", "Lundi à vendredi, 7h00–16h00")}</span>
              <span className="muted small">Bole Sub-City, Kebele 03/05, Addis Ababa</span>
              <a href="tel:+251114651300" className="bold" style={{ minHeight: 44, display: "inline-flex", alignItems: "center", alignSelf: "flex-start" }}>+251 114 651 300</a>
            </div>
          </div>
          <ol className="span-7 start-6 rule-list rule-list--strong">
            {checklist.map(([en, fr, bodyEn, bodyFr, href], i) => (
              <li key={en}>
                <div style={{ display: "grid", gridTemplateColumns: "72px 1fr", gap: 24, padding: "28px 0", justifyContent: "start", alignItems: "start" }}>
                  <span className="num" style={{ fontSize: 40, lineHeight: 1 }}>{String(i + 1).padStart(2, "0")}</span>
                  <div className="stack" style={{ gap: 8 }}>
                    <h3 className="h3" style={{ fontSize: 30 }}>{t(lang, en, fr)}</h3>
                    <p className="muted">{t(lang, bodyEn, bodyFr)}</p>
                    {href && <Link className="more arrow" href={href} style={{ minHeight: 44, display: "inline-flex", alignItems: "center", alignSelf: "flex-start" }}>{t(lang, "Visa types and fees", "Types de visa et frais")}</Link>}
                  </div>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="sec">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "Two cities", "Deux villes")} title={t(lang, "Two cities, one hour apart", "Deux villes, une heure d’écart")} />
          <div className="cols cols-2" style={{ gap: 24 }}>
            <article className="card card--dark" style={{ padding: 36, gap: 24 }}>
              <div><span className="eyebrow eyebrow--gold" style={{ fontSize: 15 }}>Burundi</span><h3 className="h3 h3--lg" style={{ fontSize: 40 }}>Bujumbura</h3></div>
              <dl className="row" style={{ gap: 40, paddingTop: 18, borderTop: "1px solid rgba(255,255,255,0.18)" }}>
                <div><dt className="sc small" style={{ color: "#C9D9C6" }}>{t(lang, "Time zone", "Fuseau")}</dt><dd className="display" style={{ fontSize: 26 }}>UTC+2</dd></div>
                <div><dt className="sc small" style={{ color: "#C9D9C6" }}>{t(lang, "Altitude", "Altitude")}</dt><dd className="display" style={{ fontSize: 26 }}>774 m</dd></div>
                <div><dt className="sc small" style={{ color: "#C9D9C6" }}>{t(lang, "Average temperature", "Température moyenne")}</dt><dd className="display" style={{ fontSize: 26 }}>23 °C</dd></div>
              </dl>
            </article>
            <article className="card card--ivory" style={{ padding: 36, gap: 24 }}>
              <div><span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "Ethiopia · the Embassy", "Éthiopie · l’Ambassade")}</span><h3 className="h3 h3--lg" style={{ fontSize: 40 }}>Addis Ababa</h3></div>
              <dl className="row" style={{ gap: 40, paddingTop: 18, borderTop: "1px solid var(--line-2)" }}>
                <div><dt className="sc small muted">{t(lang, "Time zone", "Fuseau")}</dt><dd className="display" style={{ fontSize: 26 }}>UTC+3</dd></div>
                <div><dt className="sc small muted">{t(lang, "Altitude", "Altitude")}</dt><dd className="display" style={{ fontSize: 26 }}>2,355 m</dd></div>
                <div><dt className="sc small muted">{t(lang, "Average temperature", "Température moyenne")}</dt><dd className="display" style={{ fontSize: 26 }}>16 °C</dd></div>
              </dl>
            </article>
          </div>
          <span className="row small" style={{ gap: 10, color: "#33443A" }}><span className="dot" style={{ background: "#409843" }} />{t(lang, "Live forecasts for both cities in the B4Africa app.", "Prévisions en direct pour les deux villes dans l’app B4Africa.")}</span>
        </div>
      </section>

      <section id="phrasebook" className="sec sec--ivory">
        <div className="wrap grid">
          <div className="span-4 stack" style={{ gap: 18 }}>
            <span className="eyebrow">{t(lang, "Kirundi phrasebook", "Lexique kirundi")}</span>
            <h2 className="h2 h2--md">{t(lang, "A few words go a long way", "Quelques mots font beaucoup")}</h2>
            <p className="lede lede--sm">{t(lang, "From the B4Africa app’s phrasebook: more than 600 phrases in Kirundi, English and French, in eight categories.", "Extrait du lexique de l’app B4Africa : plus de 600 phrases en kirundi, anglais et français, en huit catégories.")}</p>
            <span className="row small" style={{ gap: 10, color: "#33443A" }}><span className="dot" style={{ background: "#409843" }} />{t(lang, "Every phrase, in the B4Africa app.", "Toutes les phrases, dans l’app B4Africa.")}</span>
          </div>
          <table className="table span-7 start-6">
            <thead><tr><th>{t(lang, "English", "Anglais")}</th><th>Kirundi</th><th>{t(lang, "French", "Français")}</th></tr></thead>
            <tbody>
              {phrases.map(([en, rn, fr]) => (
                <tr key={rn}><td style={{ fontFamily: "var(--body)", fontSize: 17 }}>{en}</td><td lang="rn" className="display" style={{ fontSize: 24 }}>{rn}</td><td lang="fr" className="muted">{fr}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="sec" id="emergency">
        <div className="wrap stack stack--lg">
          <div className="between">
            <div className="stack" style={{ gap: 6 }}>
              <span className="eyebrow" style={{ color: "var(--red-ink)" }}>{t(lang, "Emergency assistance", "Assistance d’urgence")}</span>
              <h2 className="h2">{t(lang, "If something goes wrong", "En cas de problème")}</h2>
            </div>
            <p className="lede lede--sm" style={{ maxWidth: 440 }}>{t(lang, "Save these numbers before you travel. They are also in the emergency screen of the B4Africa app.", "Enregistrez ces numéros avant de partir. Ils figurent aussi dans l’écran d’urgence de l’app B4Africa.")}</p>
          </div>
          <div className="grid" style={{ alignItems: "start" }}>
            <div className="span-5 stack" style={{ gap: 20 }}>
              <div className="card card--red" style={{ padding: 36 }}>
                <span className="eyebrow" style={{ color: "var(--red-ink)", fontSize: 15 }}>{t(lang, "Embassy emergency line", "Ligne d’urgence de l’Ambassade")}</span>
                <a href="tel:+251911208857" className="display" style={{ fontSize: 36, minHeight: 44, display: "inline-flex", alignItems: "center", alignSelf: "flex-start", color: "var(--red-ink)" }}>+251 911 208 857</a>
                <p className="small" style={{ color: "#6B2226" }}>{t(lang, "For Burundians in difficulty in Ethiopia, Chad, Djibouti, Eritrea, South Sudan and Israel.", "Pour les Burundais en difficulté en Éthiopie, au Tchad, à Djibouti, en Érythrée, au Soudan du Sud et en Israël.")}</p>
                <div className="stack" style={{ gap: 2, marginTop: 8, paddingTop: 18, borderTop: "1px solid rgba(142,17,22,0.22)" }}>
                  <span className="eyebrow" style={{ color: "var(--red-ink)", fontSize: 15, marginBottom: 4 }}>{t(lang, "Embassy phones · Monday to Friday, 7:00–16:00", "Téléphones · lundi à vendredi, 7h00–16h00")}</span>
                  {["+251 114 651 300", "+251 114 655 547"].map((p) => <a key={p} href={`tel:${p.replace(/\s/g, "")}`} className="bold" style={{ minHeight: 44, display: "flex", alignItems: "center", fontSize: 18, color: "#6B2226" }}>{p}</a>)}
                  <a href="mailto:info@burundiaddis.gov.bi" className="bold" style={{ minHeight: 44, display: "flex", alignItems: "center", color: "#6B2226" }}>info@burundiaddis.gov.bi</a>
                </div>
              </div>
              <div className="card card--dark" style={{ flexDirection: "row", alignItems: "center", gap: 22 }}>
                <span aria-hidden="true" style={{ width: 84, height: 84, borderRadius: 999, background: "var(--red)", boxShadow: "0 0 0 8px rgba(225,28,35,0.25)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, fontSize: 20, fontWeight: 700, letterSpacing: "0.06em" }}>SOS</span>
                <div className="stack" style={{ gap: 4 }}>
                  <span className="display" style={{ fontSize: 24 }}>{t(lang, "SOS in the B4Africa app", "SOS dans l’app B4Africa")}</span>
                  <span className="small" style={{ color: "#C9D9C6" }}>{t(lang, "Hold the button for 3 seconds to call the emergency line.", "Maintenez le bouton 3 secondes pour appeler la ligne d’urgence.")}</span>
                </div>
              </div>
            </div>
            <div className="span-6 start-7 stack" style={{ gap: 20 }}>
              <div className="stack" style={{ gap: 4 }}><span className="eyebrow">{t(lang, "In Burundi", "Au Burundi")}</span><h3 className="h3 h3--lg">{t(lang, "Emergency numbers", "Numéros d’urgence")}</h3></div>
              {groups.length === 0 ? (
                <p className="empty">{t(lang, "Emergency numbers will be published here.", "Les numéros d’urgence seront publiés ici.")}</p>
              ) : (
                <div className="cols cols-2" style={{ gap: "28px 32px", alignItems: "start" }}>
                  {groups.map(({ cat, items }) => (
                    <div key={cat}>
                      <h4 className="sc" style={{ paddingBottom: 8, borderBottom: "2px solid var(--ink)", fontSize: 16, fontWeight: 500, color: "var(--ink-2)" }}>{t(lang, ...catLabel[cat])}</h4>
                      <ul>
                        {items.map((c) => (
                          <li key={c.id}>
                            <a href={contactHref(c)} className="no-ul" style={{ display: "flex", flexDirection: "column", padding: "12px 0", borderBottom: "1px solid var(--line)", minHeight: 44 }}>
                              <span className="row" style={{ gap: 8 }}><span className="dot" style={{ background: c.color }} /><span className="display" style={{ fontSize: 20 }}>{tr(c, "name", lang)}</span></span>
                              <span className="bold" style={{ fontSize: 17 }}>{c.contact_value}</span>
                              {tr(c, "description", lang) && <span className="small muted">{tr(c, "description", lang)}</span>}
                            </a>
                          </li>
                        ))}
                      </ul>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {missions.length > 0 && (
            <div className="stack">
              <div className="stack" style={{ gap: 4 }}><span className="eyebrow">{t(lang, "Missions of Burundi", "Missions du Burundi")}</span><h3 className="h3 h3--lg">{t(lang, "Embassies and consulates", "Ambassades et consulats")}</h3></div>
              <div className="cols cols-3">
                {missions.map((m) => (
                  <article key={m.id} className="card">
                    <span className="eyebrow" style={{ fontSize: 14 }}>{typeLabel(m.type)} · {m.country}</span>
                    <h4 className="h3 h3--sm">{tr(m, "name", lang)}</h4>
                    <span className="small muted">{m.address}{m.address && m.city ? ", " : ""}{m.city}</span>
                    {m.opening_hours && <span className="small muted">{m.opening_hours}</span>}
                    <div className="stack" style={{ gap: 0 }}>
                      {m.phone_number && <a href={`tel:${m.phone_number.replace(/[^\d+]/g, "")}`} className="bold" style={{ minHeight: 44, display: "flex", alignItems: "center" }}>{m.phone_number}</a>}
                      {m.email && <a href={`mailto:${m.email}`} style={{ minHeight: 44, display: "flex", alignItems: "center", wordBreak: "break-all" }}>{m.email}</a>}
                    </div>
                    <a className="more arrow push" href={`https://www.google.com/maps?q=${m.latitude},${m.longitude}`} rel="noopener">{t(lang, "Directions", "Itinéraire")}</a>
                  </article>
                ))}
              </div>
            </div>
          )}
        </div>
      </section>

      <section className="sec sec--ivory">
        <div className="wrap stack stack--lg">
          <div className="between">
            <div className="stack" style={{ gap: 6 }}><span className="eyebrow">{t(lang, "Where to go", "Où aller")}</span><h2 className="h2">{t(lang, "Places to see in Burundi", "À voir au Burundi")}</h2></div>
            <div className="row"><Link className="btn btn--outline btn--sm" href="/burundi#hotels">{t(lang, "Hotels in Bujumbura", "Hôtels à Bujumbura")}</Link><Link className="btn btn--sm" href="/burundi">{t(lang, "Discover Burundi", "Découvrir le Burundi")}</Link></div>
          </div>
          <div className="places">
            {([["/img/lake-tanganyika.jpg", "Lake Tanganyika", "Green hills above Lake Tanganyika", "70% center"], ["/img/karera-falls.jpg", "Karera Falls", "Karera waterfalls", ""], ["/img/gitega-museum.jpg", "Gitega National Museum", "The National Museum of Gitega", ""], ["/img/rusizi-hippos.jpg", t(lang, "Hippos on the Rusizi", "Hippopotames de la Rusizi"), "Hippos on the Rusizi", ""]] as const).map(([src, title, alt, pos], i) => (
              <Link key={title} className="stack no-ul" style={{ gap: 12 }} href="/burundi#places">
                <span className="fig" style={{ height: 340 }}><img src={src} alt={alt} style={pos ? { objectPosition: pos } : undefined} loading="lazy" /></span>
                <span className="num small">{String(i + 1).padStart(2, "0")}</span>
                <span className="h3" style={{ marginTop: -6 }}>{title}</span>
              </Link>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
