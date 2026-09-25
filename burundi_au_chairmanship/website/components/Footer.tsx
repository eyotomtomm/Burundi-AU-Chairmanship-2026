import Link from "next/link";
import type { AppSettings, Lang, SocialLink } from "@/lib/types";
import { t } from "@/lib/i18n";

export const APP_STORE = "https://apps.apple.com/app/id6740047505";
export const PLAY_STORE = "https://play.google.com/store/apps/details?id=com.b4africa.app";

export function Footer({ lang, settings, social }: { lang: Lang; settings: AppSettings | null; social: SocialLink[] }) {
  const explore = [
    ["/embassy", t(lang, "The Embassy", "L’Ambassade")],
    ["/services", t(lang, "Consular services", "Services consulaires")],
    ["/diaspora", t(lang, "Diaspora registration", "Inscription diaspora")],
    ["/travel", t(lang, "Travel & emergency", "Voyage & urgences")],
    ["/au-2026/priorities", t(lang, "AU priority agenda", "Agenda prioritaire UA")],
    ["/events", t(lang, "Events", "Événements")],
    ["/news", t(lang, "Newsroom", "Actualités")],
    ["/media", t(lang, "Media centre", "Médiathèque")],
    ["/invest", t(lang, "Invest in Burundi", "Investir au Burundi")],
  ];
  return (
    <footer className="ftr">
      <div className="wrap">
        <div className="ftr-grid">
          <div className="ftr-col span-4" style={{ gap: 18 }}>
            <img src="/img/seal.png" alt="" width={64} height={64} />
            <span className="brand-title">Ambassade de la République du Burundi</span>
            <span className="motto">Unité · Travail · Progrès</span>
          </div>
          <div className="ftr-col span-3">
            <h3>{t(lang, "Visit & contact", "Visite & contact")}</h3>
            <span>Bole Sub-City, Kebele 03/05</span>
            <span>Addis Ababa, Ethiopia</span>
            <span>{t(lang, "Monday to Friday, 7:00–16:00", "Lundi à vendredi, 7h00–16h00")}</span>
            <span>+251 114 651 300</span>
            <span>+251 114 655 547</span>
            <span>+251 911 208 857</span>
            <a href="mailto:info@burundiaddis.gov.bi" style={{ color: "#fff" }}>info@burundiaddis.gov.bi</a>
          </div>
          <div className="ftr-col span-2">
            <h3>{t(lang, "Explore", "Explorer")}</h3>
            {explore.map(([href, label]) => <Link key={href} href={href}>{label}</Link>)}
          </div>
          <div className="ftr-col span-3">
            <h3>{t(lang, "Official texts", "Textes officiels")}</h3>
            <Link href="/invest#texts">Constitution of Burundi</Link>
            <Link href="/invest#texts">Vision 2040–2060</Link>
            <Link href="/invest#texts">Investment Code · Mining Code</Link>
            <Link href="/invest#texts">PPP, VAT and Banking laws</Link>
            <Link href="/media#documents">{t(lang, "All documents", "Tous les documents")}</Link>
            <h3 style={{ marginTop: 12 }}>{t(lang, "Regional bodies", "Organisations régionales")}</h3>
            <span>AU · EAC · CEPGL · ICGLR · COMESA · ECCAS</span>
          </div>
        </div>
        <div className="ftr-bottom">
          <div className="row" style={{ gap: 18 }}>
            <img src="/img/b4africa-white.png" alt="B4Africa" width={112} height={37} style={{ width: 112, height: "auto" }} />
            <span className="small">{t(lang, "News, events and live coverage in the B4Africa app", "Actualités, événements et direct dans l’app B4Africa")}</span>
            <a className="btn btn--ghost" href={settings?.app_store_url || APP_STORE}>App Store</a>
            <a className="btn btn--ghost" href={settings?.play_store_url || PLAY_STORE}>Google Play</a>
          </div>
          <div className="ftr-links">
            {social.map((s) => <a key={s.id} href={s.url} rel="noopener">{platformLabel(s.platform)}{s.handle ? ` · ${s.handle}` : ""}</a>)}
            <span>© {new Date().getFullYear()}</span>
            <a href="/privacy-policy/">{t(lang, "Privacy", "Confidentialité")}</a>
            <a href="/terms-of-service/">{t(lang, "Terms", "Conditions")}</a>
          </div>
        </div>
      </div>
    </footer>
  );
}

const PLATFORMS: Record<string, string> = { twitter: "X", x: "X", facebook: "Facebook", instagram: "Instagram", youtube: "YouTube", linkedin: "LinkedIn", tiktok: "TikTok", whatsapp: "WhatsApp", telegram: "Telegram" };
export function platformLabel(platform: string) {
  const key = (platform || "").toLowerCase();
  return PLATFORMS[key] ?? (key ? key[0].toUpperCase() + key.slice(1) : "");
}
