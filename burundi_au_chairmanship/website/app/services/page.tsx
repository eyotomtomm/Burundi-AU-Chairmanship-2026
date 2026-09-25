import type { Metadata } from "next";
import Link from "next/link";
import { getLang, t } from "@/lib/i18n";
import { Crumbs, Ico, ICONS } from "@/components/ui";
import s from "./page.module.css";

export const metadata: Metadata = {
  title: "Consular services",
  description: "Visas, passports, laissez-passer and CEPGL cards: fees, documents and how to apply through the Embassy of Burundi in Addis Ababa.",
};

const MAIL = "mailto:info@burundiaddis.gov.bi";

export default async function Services() {
  const lang = await getLang();
  const ask = (subject: string) => `${MAIL}?subject=${encodeURIComponent(subject)}`;

  const tabs: Array<[string, string]> = [
    ["#visa", "Visa"], ["#passport", t(lang, "Passport", "Passeport")], ["#laissez-passer", "Laissez-passer"], ["#cepgl", t(lang, "CEPGL card", "Carte CEPGL")],
    ["#other", t(lang, "Legalisation", "Légalisation")], ["#other", t(lang, "Civil status", "État civil")], ["#other", t(lang, "Nationality", "Nationalité")], ["#other", t(lang, "Work permit", "Permis de travail")],
  ];

  const visas: Array<[string, string, string, string]> = [
    [t(lang, "Courtesy settlement visa", "Visa d’établissement de courtoisie"), t(lang, "Staff of embassies and organisations, on note verbale", "Personnel des ambassades et organisations, sur note verbale"), t(lang, "Free", "Gratuit"), t(lang, "2 years", "2 ans")],
    [t(lang, "Transfer of a courtesy settlement visa", "Transfert d’un visa d’établissement de courtoisie"), t(lang, "Holders with a new passport", "Titulaires d’un nouveau passeport"), t(lang, "Free", "Gratuit"), t(lang, "2 years", "2 ans")],
    [t(lang, "Certified copies, courtesy settlement visa", "Copies certifiées, visa d’établissement de courtoisie"), t(lang, "Children of holders", "Enfants des titulaires"), t(lang, "Free", "Gratuit"), t(lang, "2 years", "2 ans")],
    [t(lang, "Diplomatic settlement visa", "Visa d’établissement diplomatique"), t(lang, "Diplomatic passport holders only", "Titulaires d’un passeport diplomatique uniquement"), t(lang, "Free", "Gratuit"), t(lang, "3 years", "3 ans")],
    [t(lang, "Certified copies, permanent resident visa", "Copies certifiées, visa de résident permanent"), t(lang, "Minor children of permanent residents", "Enfants mineurs de résidents permanents"), t(lang, "Free", "Gratuit"), t(lang, "99 years", "99 ans")],
    [t(lang, "Transfer of a permanent resident visa", "Transfert d’un visa de résident permanent"), t(lang, "Holders with a new passport", "Titulaires d’un nouveau passeport"), t(lang, "Free", "Gratuit"), t(lang, "99 years", "99 ans")],
    [t(lang, "EAC entry visa", "Visa d’entrée EAC"), t(lang, "Citizens of EAC member states", "Citoyens des États membres de l’EAC"), t(lang, "Free", "Gratuit"), t(lang, "1 to 6 months", "1 à 6 mois")],
    [t(lang, "CEPGL entry visa", "Visa d’entrée CEPGL"), t(lang, "Citizens of CEPGL member states", "Citoyens des États membres de la CEPGL"), t(lang, "Free", "Gratuit"), t(lang, "1 to 3 months", "1 à 3 mois")],
    [t(lang, "EAC study visa", "Visa d’études EAC"), t(lang, "Students from EAC member states", "Étudiants des États membres de l’EAC"), t(lang, "Free", "Gratuit"), t(lang, "1 year", "1 an")],
    [t(lang, "Transit visa", "Visa de transit"), t(lang, "Travellers passing through Burundi. Issued at any point of entry", "Voyageurs en transit par le Burundi. Délivré à tout poste d’entrée"), "40 USD", t(lang, "3 days", "3 jours")],
    [t(lang, "Settlement visa", "Visa d’établissement"), t(lang, "After at least 6 months in Burundi, for employees and businesses", "Après au moins 6 mois au Burundi, pour employés et entreprises"), "500 USD", t(lang, "2 years", "2 ans")],
  ];
  const courtesyDocs = [
    t(lang, "Note verbale to the Ministry in charge of Foreign Affairs, written by the organisation (embassy or institution)", "Note verbale au Ministère en charge des Affaires étrangères, rédigée par l’organisation (ambassade ou institution)"),
    t(lang, "Letter from the Ministry of the Interior, Community Development and Public Security, approved by the Commissioner General of Migration", "Lettre du Ministère de l’Intérieur, du Développement communautaire et de la Sécurité publique, approuvée par le Commissaire général des migrations"),
    t(lang, "Copy of the passport", "Copie du passeport"),
    t(lang, "Copy of the current visa, or the entry stamp", "Copie du visa en cours, ou du cachet d’entrée"),
    t(lang, "Passport photo", "Photo d’identité"),
  ];

  const adultsStd = [
    t(lang, "Copy of the national identity card", "Copie de la carte nationale d’identité"),
    t(lang, "Full identity certificate", "Attestation d’identité complète"),
    t(lang, "Certificate of residence", "Attestation de résidence"),
    t(lang, "Proof of profession", "Justificatif de profession"),
  ];
  const expired = t(lang, "Copy of the expired passport, if any", "Copie de l’ancien passeport, le cas échéant");
  const photo = t(lang, "Passport photo", "Photo d’identité");
  const minorsStd = [
    t(lang, "Copy of the birth certificate extract", "Copie de l’extrait d’acte de naissance"),
    t(lang, "Notarised parental authorisation", "Autorisation parentale notariée"),
    t(lang, "Copies of both parents’ identity cards", "Copies des cartes d’identité des deux parents"),
    photo,
  ];
  const passports = [
    {
      title: t(lang, "Ordinary passport", "Passeport ordinaire"), fee: "235,000", note: <>{t(lang, "10 years adults", "10 ans adultes")}<br />{t(lang, "5 years children", "5 ans enfants")}</>,
      groups: [[t(lang, "Adults bring", "Adultes"), [...adultsStd, expired, photo]], [t(lang, "Minors bring", "Mineurs"), [...minorsStd, expired]]] as Array<[string, string[]]>,
    },
    {
      title: t(lang, "Service passport", "Passeport de service"), fee: "135,000", note: <>{t(lang, "For government", "Pour les missions")}<br />{t(lang, "missions", "gouvernementales")}</>,
      groups: [[t(lang, "Bring", "À fournir"), [...adultsStd, photo, t(lang, "Government mission order", "Ordre de mission gouvernemental")]]] as Array<[string, string[]]>,
    },
    {
      title: t(lang, "Diplomatic passport", "Passeport diplomatique"), fee: "135,000", note: t(lang, "5 years", "5 ans"),
      groups: [
        [t(lang, "Adults bring", "Adultes"), [...adultsStd, expired, photo, t(lang, "Note verbale from the Ministry of External Relations and Cooperation", "Note verbale du Ministère des Relations extérieures et de la Coopération")]],
        [t(lang, "Minors bring", "Mineurs"), [...minorsStd, expired, t(lang, "Copy of the parents’ diplomatic passports", "Copie des passeports diplomatiques des parents"), t(lang, "School certificate", "Attestation de scolarité")]],
      ] as Array<[string, string[]]>,
    },
  ];

  const lpSteps = [
    t(lang, "Go to the CGM reception or the provincial one-stop desk with your full file.", "Présentez-vous à l’accueil du CGM ou au guichet unique provincial avec votre dossier complet."),
    t(lang, "Fill in the application form on site. Someone is there to help.", "Remplissez le formulaire de demande sur place. Une personne est là pour vous aider."),
    t(lang, "Hand in the file for registration and sign the confirmation page.", "Déposez le dossier pour enregistrement et signez la page de confirmation."),
    t(lang, "Pay the 30,000 FBU fee at the BANCOBU counter.", "Payez les frais de 30 000 FBU au guichet BANCOBU."),
    t(lang, "Show the payment slip for your photo, and fingerprints for adults.", "Présentez le reçu de paiement pour la photo, et les empreintes pour les adultes."),
    t(lang, "Come back on the date given to collect your laissez-passer.", "Revenez à la date indiquée pour retirer votre laissez-passer."),
  ];
  const cepgl: Array<[string, string[]]> = [
    [t(lang, "Adults", "Adultes"), [t(lang, "Copy of identity card", "Copie de la carte d’identité"), adultsStd[1], adultsStd[2], adultsStd[3], photo]],
    [t(lang, "Minors", "Mineurs"), [minorsStd[0], minorsStd[1], t(lang, "Copies of parents’ identity cards", "Copies des cartes d’identité des parents"), photo, t(lang, "School certificate", "Attestation de scolarité")]],
    [t(lang, "Foreigners", "Étrangers"), [t(lang, "Copy of a valid passport", "Copie d’un passeport valide"), t(lang, "Copy of the settlement visa", "Copie du visa d’établissement"), photo]],
    [t(lang, "Renewal", "Renouvellement"), [t(lang, "Copy of the expired document", "Copie du document expiré"), t(lang, "Identity card, or birth extract for minors", "Carte d’identité, ou extrait de naissance pour les mineurs"), t(lang, "Work, student or school certificate", "Attestation de travail, d’études ou de scolarité")]],
  ];
  const others = [
    t(lang, "Legalisation of documents", "Légalisation de documents"), t(lang, "Civil marriage", "Mariage civil"), t(lang, "Administrative acts", "Actes administratifs"),
    t(lang, "Nationality", "Nationalité"), t(lang, "Work permit", "Permis de travail"),
  ];

  return (
    <>
      <section className="page-hero">
        <div className={`wrap ${s.titleRow}`}>
          <div className="stack" style={{ gap: 16, maxWidth: 760 }}>
            <Crumbs lang={lang} items={[[t(lang, "Consular services", "Services consulaires")]]} />
            <h1 className="h1">{t(lang, "Consular services", "Services consulaires")}</h1>
            <p className="lede">{t(lang, "Visas, passports and travel documents, with the fees and documents published by the Embassy. Documents are issued by the Commissariat Général des Migrations (CGM).", "Visas, passeports et documents de voyage, avec les frais et pièces publiés par l’Ambassade. Les documents sont délivrés par le Commissariat Général des Migrations (CGM).")}</p>
          </div>
          <div className={`card card--ivory ${s.visitCard}`}>
            <span className="eyebrow">{t(lang, "Visiting the Embassy", "Venir à l’Ambassade")}</span>
            <span>{t(lang, "Monday to Friday, 7:00–16:00", "Lundi à vendredi, 7h00–16h00")}</span>
            <span>Bole Sub-City, Kebele 03/05, Addis Ababa</span>
            <span>+251 114 651 300 · <a href={MAIL}>info@burundiaddis.gov.bi</a></span>
          </div>
        </div>
      </section>

      <nav aria-label={t(lang, "Services on this page", "Services sur cette page")} className={s.tabsBar}>
        <div className="wrap chips">
          {tabs.map(([href, label], i) => <a key={label} className={`chip${i === 0 ? " is-active" : ""}`} href={href}>{label}</a>)}
        </div>
      </nav>

      <section id="visa" className="sec">
        <div className="wrap stack">
          <div className="between">
            <div className="stack" style={{ gap: 6 }}><span className="eyebrow">01 · {t(lang, "Eleven visa types", "Onze types de visa")}</span><h2 className="h2">Visa</h2></div>
            <a className="btn btn--outline btn--sm" href={ask(t(lang, "Visa guide request", "Demande de guide visa"))}><Ico d={ICONS.download} size={18} stroke="currentColor" />{t(lang, "Request the full visa guide (PDF, French)", "Demander le guide complet des visas (PDF)")}</a>
          </div>
          <div className={s.tableWrap}>
            <table className={`table ${s.visaTable}`}>
              <thead><tr><th>{t(lang, "Visa type", "Type de visa")}</th><th>{t(lang, "For", "Pour")}</th><th>{t(lang, "Fee", "Frais")}</th><th>{t(lang, "Validity", "Validité")}</th></tr></thead>
              <tbody>
                {visas.map(([type, who, fee, validity]) => (
                  <tr key={type}><td>{type}</td><td className="muted">{who}</td><td className="bold">{fee}</td><td>{validity}</td></tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className={`grid ${s.bring}`}>
            <div className="span-5 stack" style={{ gap: 12 }}>
              <span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "Example · Courtesy settlement visa", "Exemple · Visa d’établissement de courtoisie")}</span>
              <h3 className="h3 h3--lg">{t(lang, "What to bring", "Pièces à fournir")}</h3>
              <p className="small muted">{t(lang, "Each visa type has its own document list like this one. Other documents may be required depending on your status.", "Chaque type de visa a sa propre liste de pièces comme celle-ci. D’autres documents peuvent être exigés selon votre situation.")}</p>
              <div className="row" style={{ marginTop: 8 }}>
                <a className="btn btn--md" href={ask(t(lang, "Visa application", "Demande de visa"))}>{t(lang, "Start this request", "Lancer cette demande")}</a>
                <a className="btn btn--outline btn--md" href={ask(t(lang, "Visa question", "Question visa"))}>{t(lang, "Ask a question", "Poser une question")}</a>
              </div>
            </div>
            <ol className={`span-6 start-7 ${s.numList}`}>
              {courtesyDocs.map((d, i) => <li key={i}><span className="num">{i + 1}</span><span>{d}</span></li>)}
            </ol>
          </div>
        </div>
      </section>

      <section id="passport" className="sec sec--ivory">
        <div className="wrap stack">
          <div className="stack" style={{ gap: 6 }}><span className="eyebrow">02 · {t(lang, "Issued by the CGM", "Délivré par le CGM")}</span><h2 className="h2">{t(lang, "Passport", "Passeport")}</h2></div>
          <div className="cols cols-3" style={{ alignItems: "start" }}>
            {passports.map((p) => (
              <article key={p.title} className="card" style={{ padding: 30, gap: 16, border: 0 }}>
                <h3 className="h3 h3--lg" style={{ fontSize: 30 }}>{p.title}</h3>
                <div className={s.fee}><span className={s.feeNum}>{p.fee}</span><span className="bold">FBU</span><span className={s.feeNote}>{p.note}</span></div>
                {p.groups.map(([label, items]) => (
                  <div key={label} className="stack" style={{ gap: 8 }}>
                    <span className="eyebrow" style={{ fontSize: 15 }}>{label}</span>
                    <ul className={s.bullets}>{items.map((it) => <li key={it}>{it}</li>)}</ul>
                  </div>
                ))}
              </article>
            ))}
          </div>
        </div>
      </section>

      <section id="laissez-passer" className="sec">
        <div className="wrap stack">
          <div className="stack" style={{ gap: 6 }}><span className="eyebrow">03 · {t(lang, "Regional travel documents", "Documents de voyage régionaux")}</span><h2 className="h2">{t(lang, "Laissez-passer and CEPGL card", "Laissez-passer et carte CEPGL")}</h2></div>
          <div className="cols cols-2" style={{ gap: 24, alignItems: "start" }}>
            <article className="card" style={{ padding: 34, gap: 18 }}>
              <h3 className="h3 h3--lg">Laissez-passer</h3>
              <p className="muted">{t(lang, "Required for Burundians travelling to other EAC countries: Kenya, Rwanda, Uganda, Tanzania and South Sudan.", "Requis pour les Burundais se rendant dans les autres pays de l’EAC : Kenya, Rwanda, Ouganda, Tanzanie et Soudan du Sud.")}</p>
              <div className="row"><span className={s.fact}>30,000 FBU</span><span className={s.fact}>{t(lang, "Valid 1 year", "Valable 1 an")}</span></div>
              <span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "Bring", "À fournir")}</span>
              <ul className={s.bullets}>
                <li>{t(lang, "One passport photo on a white background", "Une photo d’identité sur fond blanc")}</li>
                <li>{adultsStd[0]}</li><li>{adultsStd[1]}</li><li>{adultsStd[2]}</li>
              </ul>
              <span className="eyebrow" style={{ fontSize: 15 }}>{t(lang, "Steps", "Étapes")}</span>
              <ol className={s.steps}>{lpSteps.map((st, i) => <li key={i}><span>{i + 1}</span><span>{st}</span></li>)}</ol>
            </article>
            <article id="cepgl" className="card" style={{ padding: 34, gap: 18 }}>
              <h3 className="h3 h3--lg">{t(lang, "CEPGL card", "Carte CEPGL")}</h3>
              <p className="muted">{t(lang, "For travel within the countries of the Economic Community of the Great Lakes Countries.", "Pour circuler dans les pays de la Communauté économique des pays des Grands Lacs.")}</p>
              <div className="row"><span className={s.fact}>18,000 FBU</span><span className={s.fact}>{t(lang, "1 year for nationals", "1 an pour les nationaux")}</span><span className={s.fact}>{t(lang, "3 months for resident expatriates", "3 mois pour les expatriés résidents")}</span></div>
              <div className="cols cols-2" style={{ gap: "20px 24px" }}>
                {cepgl.map(([label, items]) => (
                  <div key={label} className="stack" style={{ gap: 8 }}>
                    <span className="eyebrow" style={{ fontSize: 15 }}>{label}</span>
                    <ul className={s.bullets}>{items.map((it) => <li key={it}>{it}</li>)}</ul>
                  </div>
                ))}
              </div>
            </article>
          </div>
        </div>
      </section>

      <section id="other" className="sec sec--ivory">
        <div className="wrap stack">
          <div className="stack" style={{ gap: 6 }}><span className="eyebrow">04 · {t(lang, "Civil and administrative", "Civil et administratif")}</span><h2 className="h2">{t(lang, "Other services", "Autres services")}</h2></div>
          <div className="cols cols-5">
            {others.map((o) => (
              <a key={o} className="card" style={{ border: 0, minHeight: 180, padding: 24, gap: 10 }} href={ask(o)}>
                <span className="h3" style={{ fontSize: 25 }}>{o}</span>
                <span className="small muted">{t(lang, "Requirements on request from the consular desk.", "Pièces à fournir sur demande auprès du service consulaire.")}</span>
                <span className="push small bold arrow">{t(lang, "Ask the consular desk", "Contacter le service consulaire")}</span>
              </a>
            ))}
          </div>
        </div>
      </section>

      <section className="sec sec--tight">
        <div className="wrap">
          <div className={s.helpBand}>
            <div className="stack" style={{ gap: 8 }}>
              <h2 className="h2 h2--md" style={{ fontSize: 40 }}>{t(lang, "Not sure what you need?", "Vous ne savez pas quoi demander ?")}</h2>
              <p style={{ fontSize: 17, color: "#C9D9C6" }}>{t(lang, "Send your question to the consular desk, or ask from the B4Africa app.", "Envoyez votre question au service consulaire, ou posez-la depuis l’app B4Africa.")}</p>
            </div>
            <div className="row" style={{ flexShrink: 0 }}>
              <a className="btn btn--gold btn--md" href={ask(t(lang, "Consular question", "Question consulaire"))}>{t(lang, "Ask a question", "Poser une question")}</a>
              <a className="btn btn--ghost btn--md" href="tel:+251114651300">{t(lang, "Call", "Appeler")} +251 114 651 300</a>
              <Link className="btn btn--ghost btn--md" href="/travel#emergency">{t(lang, "Emergency", "Urgence")}</Link>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
