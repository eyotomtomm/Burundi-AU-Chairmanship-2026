import type { Metadata } from "next";
import Link from "next/link";
import { api, media } from "@/lib/api";
import { excerpt, fmtDate, fmtTime, getLang, t, tr } from "@/lib/i18n";
import type { Event, Lang } from "@/lib/types";
import { Crumbs, Empty, Ico, ICONS, SectionHead } from "@/components/ui";

export const metadata: Metadata = {
  title: "Events & Continental Dialogue",
  description: "Official events, conferences and webinars of Burundi’s AU Chairmanship 2026, and the Continental Dialogue on Youth, Peace & Security.",
};

const HOLIDAYS = [
  ["2026-10-13", "Anniversary of the assassination of Prince Louis Rwagasore", "Anniversaire de l’assassinat du Prince Louis Rwagasore"],
  ["2026-10-21", "Anniversary of the assassination of President Melchior Ndadaye", "Anniversaire de l’assassinat du Président Melchior Ndadaye"],
  ["2027-03-08", "International Women’s Day", "Journée internationale des femmes"],
  ["2027-04-06", "Anniversary of the assassination of President Cyprien Ntaryamira", "Anniversaire de l’assassinat du Président Cyprien Ntaryamira"],
  ["2027-05-01", "Labour Day", "Fête du Travail"],
  ["2027-07-01", "Independence Day", "Fête de l’Indépendance"],
];

function DateBlock({ iso, lang }: { iso: string; lang: Lang }) {
  const d = new Date(iso);
  const f = (o: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat(lang === "fr" ? "fr-FR" : "en-GB", { timeZone: "Africa/Addis_Ababa", ...o }).format(d);
  return (
    <div className="stack" style={{ gap: 2, minWidth: 96, textAlign: "center", padding: "14px 10px", borderRadius: 16, background: "var(--ivory)" }}>
      <span className="sc" style={{ fontSize: 14, color: "var(--gold-ink)" }}>{f({ month: "short" })}</span>
      <span className="display" style={{ fontSize: 44, lineHeight: 1 }}>{f({ day: "2-digit" })}</span>
      <span className="small muted">{f({ weekday: "short" })}</span>
    </div>
  );
}

function EventRow({ e, lang, past = false }: { e: Event; lang: Lang; past?: boolean }) {
  const img = media(e.medium_url || e.image);
  return (
    <li id={`event-${e.id}`} className="card" style={{ flexDirection: "row", gap: 24, alignItems: "flex-start", flexWrap: "wrap" }}>
      <DateBlock iso={e.event_date} lang={lang} />
      <div className="stack" style={{ gap: 10, flex: "1 1 320px" }}>
        <div className="row" style={{ gap: 8 }}>
          <span className="tag" style={{ background: past ? "var(--line)" : "var(--gold)" }}>{past ? t(lang, "Ended", "Terminé") : t(lang, "Upcoming", "À venir")}</span>
          {e.recurrence_type && e.recurrence_type !== "none" && <span className="tag" style={{ background: "var(--ivory)" }}>{t(lang, "Recurring", "Récurrent")}</span>}
        </div>
        <h3 className="h3">{tr(e, "name", lang)}</h3>
        <p className="muted">{fmtTime(e.event_date, lang)}{e.address ? ` · ${e.address}` : ""}</p>
        {e.description && <p className="small muted">{excerpt(tr(e, "description", lang), 36)}</p>}
        <div className="row" style={{ gap: 16 }}>
          {e.map_url && <a className="more arrow" href={e.map_url} rel="noopener">{t(lang, "Directions", "Itinéraire")}</a>}
          {!past && <Link className="more arrow" href="/app">{t(lang, "Reminder in the app", "Rappel dans l’app")}</Link>}
        </div>
      </div>
      {img && <img src={img} alt="" loading="lazy" style={{ width: 200, height: 140, objectFit: "cover", borderRadius: 14 }} />}
    </li>
  );
}

export default async function EventsPage({ searchParams }: { searchParams: Promise<{ when?: string }> }) {
  const lang = await getLang();
  const { when } = await searchParams;
  const now = new Date().getTime();
  const [events, regs, live] = await Promise.all([api.events({ page_size: 100 }), api.registrations(), api.live()]);
  const sorted = [...events.results].sort((a, b) => a.event_date.localeCompare(b.event_date));
  const upcoming = sorted.filter((e) => new Date(e.event_date).getTime() >= now);
  const past = sorted.filter((e) => new Date(e.event_date).getTime() < now).reverse().slice(0, 6);
  const showUpcoming = when !== "past";
  const showPast = when !== "upcoming";
  const openRegs = regs.results.filter((r) => r.is_registration_enabled && (!r.event_date || new Date(r.event_date).getTime() >= now));
  const liveNow = live.results.find((l) => l.status === "live");

  return (
    <>
      <section className="page-hero">
        <div className="wrap grid grid--center">
          <div className="span-6 stack" style={{ gap: 24 }}>
            <Crumbs lang={lang} items={[["AU 2026", "/au-2026"], [t(lang, "Events", "Événements")]]} />
            <h1 className="h1">{lang === "fr" ? <>Les événements de <em className="hl">l’année de présidence</em></> : <>Events of the <em className="hl">chairmanship year</em></>}</h1>
            <p className="lede">{t(lang, "Official events, conferences and webinars of Burundi’s AU Chairmanship 2026. Register here on the website; your ticket and check-in then live in the B4Africa app, on the same account.", "Événements officiels, conférences et webinaires de la Présidence burundaise de l’UA 2026. Inscrivez-vous ici sur le site ; votre billet et votre enregistrement vous suivent dans l’app B4Africa, avec le même compte.")}</p>
            <ol className="cols cols-3" style={{ paddingTop: 18, borderTop: "1px solid var(--line)" }}>
              {[t(lang, "Register on the website", "Inscrivez-vous sur le site"), t(lang, "Get your ticket in the B4Africa app", "Recevez votre billet dans l’app B4Africa"), t(lang, "Scan in at the venue gate", "Scannez à l’entrée du lieu")].map((s, i) => (
                <li key={s} className="stack" style={{ gap: 4 }}><span className="num" style={{ fontSize: 15 }}>{String(i + 1).padStart(2, "0")}</span><span className="bold">{s}</span></li>
              ))}
            </ol>
            <div className="row btn-row"><a className="btn" href="#upcoming">{t(lang, "Upcoming events", "Événements à venir")}</a><a className="btn btn--outline" href="#dialogue">{t(lang, "Continental Dialogue", "Dialogue continental")}</a></div>
          </div>
          <figure className="span-5 start-8">
            <div className="fig fig--4x3"><img src="/img/president-youth.jpg" alt="President Évariste Ndayishimiye with young delegates" style={{ objectPosition: "center 30%" }} /></div>
            <figcaption className="caption">{t(lang, "5th Continental Dialogue on Youth, Peace & Security, Bujumbura, August 2026", "5e Dialogue continental sur la jeunesse, la paix et la sécurité, Bujumbura, août 2026")}</figcaption>
          </figure>
        </div>
      </section>

      <nav aria-label={t(lang, "Filter events", "Filtrer les événements")} className="sec--ivory" style={{ padding: "18px 0", borderTop: "1px solid var(--line)", borderBottom: "1px solid var(--line)" }}>
        <div className="wrap between" style={{ alignItems: "center" }}>
          <div className="chips">
            <Link className="chip" href="/events" aria-current={!when ? "true" : undefined}>{t(lang, "All", "Tout")}</Link>
            <Link className="chip" href="/events?when=upcoming" aria-current={when === "upcoming" ? "true" : undefined}>{t(lang, "Upcoming", "À venir")}</Link>
            <Link className="chip" href="/events?when=past" aria-current={when === "past" ? "true" : undefined}>{t(lang, "Past", "Passés")}</Link>
          </div>
          <Link className="more arrow" href="/app">{t(lang, "Event reminders in the B4Africa app", "Rappels d’événements dans l’app B4Africa")}</Link>
        </div>
      </nav>

      {liveNow && (
        <section className="sec--dark" style={{ padding: "28px 0" }}>
          <div className="wrap between" style={{ alignItems: "center" }}>
            <div className="row" style={{ gap: 16 }}><span className="tag tag--live">LIVE</span><span className="h3 h3--sm">{tr(liveNow, "title", lang)}</span></div>
            <a className="btn btn--gold btn--sm" href={liveNow.stream_url} rel="noopener">{t(lang, "Watch now", "Regarder")}</a>
          </div>
        </section>
      )}

      {showUpcoming && (
        <section id="upcoming" className="sec">
          <div className="wrap stack">
            <SectionHead eyebrow={t(lang, "Upcoming", "À venir")} title={t(lang, "Next on the calendar", "Prochainement au calendrier")} />
            <p className="lede lede--sm">{t(lang, "Dates and venues are published here as each event is confirmed. Register on this page; reminders arrive in the B4Africa app.", "Les dates et lieux sont publiés ici au fur et à mesure des confirmations. Inscrivez-vous sur cette page ; les rappels arrivent dans l’app B4Africa.")}</p>
            {upcoming.length || openRegs.length ? (
              <ul className="stack stack--sm">
                {openRegs.map((r) => (
                  <li key={`reg-${r.id}`} className="card" style={{ flexDirection: "row", gap: 24, alignItems: "flex-start", flexWrap: "wrap" }}>
                    {r.event_date && <DateBlock iso={r.event_date} lang={lang} />}
                    <div className="stack" style={{ gap: 10, flex: "1 1 320px" }}>
                      <div className="row" style={{ gap: 8 }}>
                        {r.category && <span className="tag tag--gold">{tr(r.category, "name", lang)}</span>}
                        <span className="tag" style={{ background: "var(--ivory)" }}>{{ in_person: t(lang, "In person", "En présentiel"), online: t(lang, "Online", "En ligne"), hybrid: t(lang, "Hybrid", "Hybride") }[r.event_type]}</span>
                      </div>
                      <h3 className="h3">{tr(r, "event_title", lang)}</h3>
                      <p className="muted">{r.event_date ? fmtTime(r.event_date, lang) : ""}{r.venue ? ` · ${tr(r, "venue", lang)}` : ""}{r.venue_address ? `, ${r.venue_address}` : ""}</p>
                      <div className="row" style={{ gap: 16 }}>
                        <span className="small bold" style={{ color: "#1B6B2E" }}>{t(lang, "Registration open", "Inscriptions ouvertes")}</span>
                        {r.registration_deadline && <span className="small muted">{t(lang, "Closes", "Clôture")} {fmtDate(r.registration_deadline, lang)}</span>}
                      </div>
                    </div>
                    <a className="btn btn--md" href={`https://burundi4africa.com/register?event=${r.id}`}>{t(lang, "Register", "S’inscrire")}</a>
                  </li>
                ))}
                {upcoming.map((e) => <EventRow key={e.id} e={e} lang={lang} />)}
              </ul>
            ) : (
              <Empty>{t(lang, "No upcoming event is confirmed yet. New dates appear here first.", "Aucun événement à venir n’est encore confirmé. Les nouvelles dates apparaissent ici en premier.")}</Empty>
            )}
          </div>
        </section>
      )}

      <section id="register" className="sec sec--ivory">
        <div className="wrap grid">
          <div className="span-5 stack" style={{ gap: 18 }}>
            <span className="eyebrow">{t(lang, "How an event page works", "Comment fonctionne une page d’événement")}</span>
            <h2 className="h2">{t(lang, "Read, register, get your ticket", "Lire, s’inscrire, recevoir son billet")}</h2>
            <p className="lede lede--sm">{t(lang, "Every event has one page like this. Register on the website and your ticket follows you into the B4Africa app, on the same account.", "Chaque événement a une page comme celle-ci. Inscrivez-vous sur le site et votre billet vous suit dans l’app B4Africa, avec le même compte.")}</p>
            <ul className="rule-list">
              {[
                [ICONS.doc, t(lang, "Date, time, venue, agenda and speakers on one page", "Date, heure, lieu, programme et intervenants sur une page")],
                [ICONS.users, t(lang, "Register yourself, or register for someone else", "Inscrivez-vous, ou inscrivez quelqu’un d’autre")],
                [ICONS.calendar, t(lang, "Your ticket with its check-in QR code, also in the app", "Votre billet avec son QR code d’enregistrement, aussi dans l’app")],
              ].map(([d, s]) => <li key={s}><div><span className="row" style={{ gap: 14 }}><span className="icon-circle icon-circle--white"><Ico d={d} /></span><span>{s}</span></span></div></li>)}
            </ul>
            <div className="row btn-row"><a className="btn" href="https://burundi4africa.com/register">{t(lang, "Open the registration form", "Ouvrir le formulaire d’inscription")}</a><Link className="btn btn--outline" href="/app">{t(lang, "Get the app", "Télécharger l’app")}</Link></div>
          </div>
          <article className="span-6 start-7 card card--flush" aria-label={t(lang, "Example event ticket", "Exemple de billet")}>
            <img src="/img/handshake.jpg" alt="" loading="lazy" style={{ width: "100%", height: 260, objectFit: "cover" }} />
            <div className="card-body">
              <div className="row" style={{ gap: 8 }}><span className="tag tag--gold">{t(lang, "Registration open", "Inscriptions ouvertes")}</span><span className="tag" style={{ background: "var(--ivory)" }}>{t(lang, "Live streamed", "Diffusé en direct")}</span></div>
              <h3 className="h3">{t(lang, "Event ticket", "Billet d’événement")}</h3>
              <dl className="dl">
                <dt>{t(lang, "Attendee", "Participant")}</dt><dd>{t(lang, "Your full name", "Votre nom complet")}</dd>
                <dt>{t(lang, "Status", "Statut")}</dt><dd>{t(lang, "Approved", "Approuvé")}</dd>
                <dt>{t(lang, "Check-in", "Enregistrement")}</dt><dd>{t(lang, "Scan the QR code at the venue gate", "Scannez le QR code à l’entrée")}</dd>
              </dl>
              <p className="small muted">{t(lang, "Your ticket is also in the B4Africa app.", "Votre billet est aussi dans l’app B4Africa.")}</p>
            </div>
          </article>
        </div>
      </section>

      <section id="dialogue" className="sec">
        <div className="wrap stack stack--lg">
          <div className="grid grid--center">
            <div className="span-6 stack" style={{ gap: 18 }}>
              <span className="eyebrow">{t(lang, "Continental Dialogue on Youth, Peace & Security", "Dialogue continental sur la jeunesse, la paix et la sécurité")}</span>
              <h2 className="h2">{t(lang, "Apply once, then carry your Digital ID", "Postulez une fois, puis gardez votre ID numérique")}</h2>
              <p className="lede lede--sm">{t(lang, "President Évariste Ndayishimiye is the African Union Champion for Youth, Peace and Security, and the 36th AU Summit (February 2023) endorsed an annual dialogue in Bujumbura. The first was held on 23 April 2022 at Hotel Club du Lac; the 5th edition took place in Bujumbura in August 2026, alongside the Women, Peace & Security agenda.", "Le Président Évariste Ndayishimiye est le Champion de l’Union africaine pour la jeunesse, la paix et la sécurité ; le 36e Sommet de l’UA (février 2023) a entériné un dialogue annuel à Bujumbura. Le premier s’est tenu le 23 avril 2022 à l’Hôtel Club du Lac ; la 5e édition a eu lieu à Bujumbura en août 2026, aux côtés de l’agenda Femmes, paix et sécurité.")}</p>
            </div>
            <figure className="span-5 start-8 fig fig--4x3"><img src="/img/president-youth.jpg" alt="President Évariste Ndayishimiye with young delegates at the 5th Continental Dialogue" loading="lazy" style={{ objectPosition: "center 30%" }} /></figure>
          </div>
          <ol className="cols cols-5">
            {[
              [t(lang, "Applied", "Candidature"), t(lang, "Fill in the application form, on the website or in the app.", "Remplissez le formulaire, sur le site ou dans l’app.")],
              [t(lang, "Under review", "En examen"), t(lang, "Our committee is reviewing your application.", "Notre comité examine votre candidature.")],
              [t(lang, "Documents", "Documents"), t(lang, "If accepted, upload the required documents.", "Si vous êtes accepté, téléversez les documents requis.")],
              [t(lang, "Verification", "Vérification"), t(lang, "Our team will verify each document you submit.", "Notre équipe vérifie chaque document soumis.")],
              [t(lang, "Digital ID", "ID numérique"), t(lang, "Once verified, your Digital ID will be issued automatically.", "Une fois vérifié, votre ID numérique est émis automatiquement.")],
            ].map(([h, p], i) => <li key={h} className="card card--ivory"><span className="num" style={{ fontSize: 28 }}>{i + 1}</span><span className="h3 h3--sm">{h}</span><span className="small muted">{p}</span></li>)}
          </ol>
          <div className="grid">
            <div className="span-7 card">
              <span className="eyebrow">{t(lang, "The application form", "Le formulaire de candidature")}</span>
              <h3 className="h3">{t(lang, "What we ask for", "Ce que nous demandons")}</h3>
              <ul className="cols cols-2" style={{ gap: "8px 24px" }}>
                {[t(lang, "Title", "Civilité"), t(lang, "First name", "Prénom"), t(lang, "Last name", "Nom"), t(lang, "Date of birth", "Date de naissance"), t(lang, "Gender", "Genre"), t(lang, "Email, verified by code", "E-mail, vérifié par code"), t(lang, "Phone", "Téléphone"), t(lang, "Nationality", "Nationalité"), t(lang, "Organization", "Organisation"), t(lang, "Position / role", "Poste / rôle")].map((f) => <li key={f} className="row" style={{ gap: 10 }}><span className="dot" />{f}</li>)}
              </ul>
              <p className="small muted" style={{ marginTop: 8 }}><b>{t(lang, "Motivation", "Motivation")}</b> · {t(lang, "“Why do you want to participate?”", "« Pourquoi souhaitez-vous participer ? »")}</p>
              <p className="small muted"><b>Documents</b> · {t(lang, "PDF, JPG, PNG, max 5 MB per file. Burundian nationals may upload a national ID or a passport; other nationals upload a passport.", "PDF, JPG, PNG, 5 Mo max par fichier. Les Burundais peuvent téléverser une carte d’identité ou un passeport ; les autres un passeport.")}</p>
            </div>
            <div className="span-5 card card--dark" style={{ justifyContent: "space-between" }}>
              <span className="eyebrow eyebrow--gold">{t(lang, "Continental Dialogue programme", "Programme du Dialogue continental")}</span>
              <h3 className="h3">{t(lang, "Applications for the next edition open here first", "Les candidatures de la prochaine édition ouvrent ici en premier")}</h3>
              <p style={{ color: "#C9D9C6" }}>{t(lang, "Your application, documents and Digital ID all live in the B4Africa app. The ID works offline, at every venue gate.", "Votre candidature, vos documents et votre ID numérique vivent dans l’app B4Africa. L’ID fonctionne hors ligne, à chaque entrée.")}</p>
              <div className="row btn-row"><Link className="btn btn--gold btn--md" href="/app">{t(lang, "Get notified in the app", "Être notifié dans l’app")}</Link><Link className="btn btn--ghost btn--md" href="/au-2026/priorities#peace-security">{t(lang, "Peace & Security priority", "Priorité Paix et sécurité")}</Link></div>
            </div>
          </div>
        </div>
      </section>

      {showPast && (
        <section className="sec sec--ivory">
          <div className="wrap stack">
            <SectionHead eyebrow={t(lang, "Past events", "Événements passés")} title={t(lang, "Earlier this year", "Plus tôt cette année")} more={t(lang, "All news", "Toutes les actualités")} moreHref="/news" />
            {past.length ? <ul className="stack stack--sm">{past.map((e) => <EventRow key={e.id} e={e} lang={lang} past />)}</ul> : <Empty>{t(lang, "Past events will be listed here.", "Les événements passés seront listés ici.")}</Empty>}
          </div>
        </section>
      )}

      <section className="sec">
        <div className="wrap stack">
          <SectionHead eyebrow={t(lang, "National calendar", "Calendrier national")} title={t(lang, "Upcoming public holidays in Burundi", "Prochains jours fériés au Burundi")} />
          <p className="lede lede--sm">{t(lang, "From the Embassy’s published list of public holidays. Religious holidays follow the official calendar.", "D’après la liste des jours fériés publiée par l’Ambassade. Les fêtes religieuses suivent le calendrier officiel.")}</p>
          <ol className="rule-list">
            {HOLIDAYS.map(([iso, en, fr], i) => (
              <li key={iso}><div>
                <span className="row" style={{ gap: 18 }}>
                  <span className="sc" style={{ minWidth: 200, color: "var(--gold-ink)" }}>{fmtDate(iso + "T12:00:00Z", lang, { weekday: "long" })}</span>
                  <span className="h3 h3--sm">{t(lang, en, fr)}</span>
                </span>
                {i === 0 && <span className="tag tag--gold">{t(lang, "Next", "Prochain")}</span>}
              </div></li>
            ))}
          </ol>
        </div>
      </section>
    </>
  );
}
