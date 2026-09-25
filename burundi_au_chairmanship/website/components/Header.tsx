import Link from "next/link";
import { headers } from "next/headers";
import type { Lang } from "@/lib/types";
import { t } from "@/lib/i18n";
import { Clock } from "./Clock";
import { NavLink } from "./NavLink";
import { navGroups } from "./nav";

const Chevron = () => (
  <svg aria-hidden="true" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M6 9l6 6 6-6" /></svg>
);

export async function Header({ lang }: { lang: Lang }) {
  const h = await headers();
  // Set by proxy.ts so the language toggle can return to the current page.
  const path = h.get("x-pathname") ?? "/";
  const groups = navGroups(lang);
  return (
    <>
      <div className="topbar">
        <div className="wrap">
          <span className="official">
            {t(lang, "Official website of the Embassy of the Republic of Burundi in Addis Ababa", "Site officiel de l’Ambassade de la République du Burundi à Addis-Abeba")}
          </span>
          <div className="row" style={{ gap: 22 }}>
            <Clock />
            <Link href="/travel#emergency"><span className="dot dot--red" />{t(lang, "Emergency assistance", "Assistance d’urgence")}</Link>
            <span className="lang">
              <a href={`/lang/en?next=${encodeURIComponent(path)}`} aria-current={lang === "en" ? "true" : undefined} hrefLang="en">EN</a>
              <a href={`/lang/fr?next=${encodeURIComponent(path)}`} aria-current={lang === "fr" ? "true" : undefined} hrefLang="fr">FR</a>
            </span>
          </div>
        </div>
      </div>
      <header className="hdr">
        <div className="wrap">
          <Link className="brand" href="/">
            <img src="/img/seal.png" alt="Seal of the Embassy of Burundi in Addis Ababa" width={54} height={54} />
            <span>
              <b>{t(lang, "Embassy of Burundi", "Ambassade du Burundi")}</b>
              <i>Addis Ababa · {t(lang, "Permanent Mission to the AU", "Mission permanente auprès de l’UA")}</i>
            </span>
          </Link>
          <nav className="nav" aria-label="Main">
            {groups.map((g) => g.children.length === 0 ? (
              <div key={g.href} className="nav-item nav-item--plain"><NavLink href={g.href}>{g.label}</NavLink></div>
            ) : (
              <div key={g.href} className="nav-item">
                <NavLink href={g.href}>{g.label}<Chevron /></NavLink>
                <div className="sub" role="group" aria-label={g.label}>
                  {g.children.map((c) => (
                    <Link key={c.href} href={c.href}>{c.label}{c.hint && <small>{c.hint}</small>}</Link>
                  ))}
                </div>
              </div>
            ))}
          </nav>
          <div className="hdr-actions">
            <Link className="icon-btn" href="/news#search" aria-label={t(lang, "Search", "Rechercher")}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><circle cx="11" cy="11" r="7" /><path d="M20 20l-3.5-3.5" /></svg>
            </Link>
            <Link className="btn btn--sm" href="/services">{t(lang, "Apply online", "Démarches en ligne")}</Link>
            <details className="menu">
              <summary className="icon-btn" aria-label={t(lang, "Open menu", "Ouvrir le menu")}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M4 7h16M4 12h16M4 17h16" /></svg>
              </summary>
              <div className="menu-panel">
                {groups.map((g) => g.children.length === 0 ? (
                  <Link key={g.href} href={g.href}>{g.label}</Link>
                ) : (
                  <details key={g.href}>
                    <summary>{g.label}<Chevron /></summary>
                    <Link href={g.href}>{t(lang, "Overview", "Aperçu")} · {g.label}</Link>
                    {g.children.filter((c) => c.href !== g.href).map((c) => (
                      <Link key={c.href} href={c.href}>{c.label}{c.hint && <small>{c.hint}</small>}</Link>
                    ))}
                  </details>
                ))}
                <Link href="/news#search">{t(lang, "Search", "Rechercher")}</Link>
                <Link href="/services">{t(lang, "Apply online", "Démarches en ligne")}</Link>
              </div>
            </details>
          </div>
        </div>
      </header>
    </>
  );
}
