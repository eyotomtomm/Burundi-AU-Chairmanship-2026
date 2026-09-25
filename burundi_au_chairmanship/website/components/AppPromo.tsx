import type { AppSettings, Lang } from "@/lib/types";
import { t } from "@/lib/i18n";
import { APP_STORE, PLAY_STORE } from "./Footer";

const Icon = ({ d }: { d: string }) => (
  <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#FCD116" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>
);
const Down = () => (
  <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0F2A1B" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 4v11M7 10l5 5 5-5M5 20h14" /></svg>
);

export function AppPromo({ lang, settings }: { lang: Lang; settings: AppSettings | null }) {
  const features: Array<[string, string, string]> = [
    ["M12 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0-4 0M8.5 8.5a5 5 0 0 0 0 7M15.5 8.5a5 5 0 0 1 0 7M5.6 5.6a9 9 0 0 0 0 12.8M18.4 5.6a9 9 0 0 1 0 12.8", "Live coverage and alerts", "Direct et alertes"],
    ["M3 8a2 2 0 0 0 2-2h14a2 2 0 0 0 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 0-2 2H5a2 2 0 0 0-2-2v-2a2 2 0 0 0 0-4zM14 6v12", "Event tickets and check-in", "Billets et enregistrement"],
    ["M2 4h6a4 4 0 0 1 4 4v13a3 3 0 0 0-3-3H2zM22 4h-6a4 4 0 0 0-4 4v13a3 3 0 0 1 3-3h7z", "Digital magazine, offline", "Magazine numérique, hors ligne"],
    ["M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 12m-5 0a5 5 0 1 0 10 0a5 5 0 1 0-10 0M12 12m-1 0a1 1 0 1 0 2 0a1 1 0 1 0-2 0", "The priority agenda", "L’agenda prioritaire"],
    ["M3 5h18v14H3zM9 11m-2 0a2 2 0 1 0 4 0a2 2 0 1 0-4 0M6 16a3 3 0 0 1 6 0M14 10h4M14 13h3", "Continental Dialogue ID", "ID du Dialogue continental"],
    ["M4 5h16v11H9l-5 4zM8 9h8M8 12h5", "Kirundi phrasebook and SOS", "Lexique kirundi et SOS"],
  ];
  return (
    <section className="promo" aria-labelledby="promo-title">
      <div className="wrap">
        <div className="promo-copy">
          <div className="row" style={{ gap: 16 }}>
            <img src="/img/b4africa-white.png" alt="B4Africa" width={112} height={37} style={{ width: 112, height: "auto" }} />
            <span style={{ width: 1, height: 28, background: "rgba(255,255,255,0.35)" }} />
            <span className="sc" style={{ color: "#fff" }}>{t(lang, "Official app · AU Chairmanship 2026", "Application officielle · Présidence de l’UA 2026")}</span>
          </div>
          <h2 id="promo-title">
            {lang === "fr" ? <>La présidence, <em>dans votre poche</em></> : <>The chairmanship, <em>in your pocket</em></>}
          </h2>
          <p>
            {t(lang,
              "The official application of the Republic of Burundi’s African Union Chairmanship, carrying the summit’s news, events, publications and the voices of the young Africans shaping its agenda.",
              "L’application officielle de la Présidence burundaise de l’Union africaine : actualités du sommet, événements, publications et les voix des jeunes Africains qui façonnent son agenda.")}
          </p>
          <ul className="promo-list">
            {features.map(([d, en, fr]) => <li key={en}><Icon d={d} />{t(lang, en, fr)}</li>)}
          </ul>
          <div className="row" style={{ gap: 20, marginTop: 6 }}>
            <div className="stack" style={{ gap: 10 }}>
              <a className="store" href={settings?.app_store_url || APP_STORE}><Down /><span><small>{t(lang, "Download on the", "Télécharger sur l’")}</small><b>App Store</b></span></a>
              <a className="store" href={settings?.play_store_url || PLAY_STORE}><Down /><span><small>{t(lang, "Get it on", "Disponible sur")}</small><b>Google Play</b></span></a>
            </div>
            <span className="small" style={{ color: "#E3EEDF" }}><b style={{ display: "block", color: "#fff" }}>{t(lang, "Or on the web", "Ou sur le web")}</b>burundi4africa.com/app</span>
          </div>
        </div>
        <Phone lang={lang} />
      </div>
    </section>
  );
}

function Phone({ lang }: { lang: Lang }) {
  const qa = ["Live", "Magazine", "Resources", "News", "Translate", "Weather", "Calendar", "Events"];
  return (
    <div className="phone" role="img" aria-label="The B4Africa app home screen">
      <div className="phone-screen">
        <div style={{ background: "#409843", borderRadius: "0 0 22px 22px", padding: "44px 14px 14px", color: "#fff" }}>
          <div style={{ fontSize: 9, opacity: 0.75 }}>Bwiriwe</div>
          <div style={{ fontSize: 17, fontWeight: 900, letterSpacing: -0.3 }}>{t(lang, "Good afternoon", "Bonjour")}</div>
          <div style={{ marginTop: 12, fontSize: 10, fontWeight: 700 }}>New today</div>
          <div style={{ display: "flex", gap: 8, marginTop: 8, width: 400 }}>
            {[["/img/au-hq-duotone.jpg", "NEWS", "Roundtable on Burundi’s Presidency of the African Union"], ["/img/lake-tanganyika.jpg", "DISCOVER", "Discover Burundi"]].map(([src, tag, title]) => (
              <div key={tag} style={{ width: 170, flexShrink: 0, borderRadius: 13, overflow: "hidden", background: "#fff", color: "#1A1A1A", boxShadow: "0 4px 12px rgba(0,0,0,.12)" }}>
                <div style={{ position: "relative", height: 66 }}>
                  <img src={src} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                  <span style={{ position: "absolute", left: 7, top: 7, background: "#FFF7DA", color: "#8A6D00", fontSize: 7.5, fontWeight: 700, padding: "2px 7px", borderRadius: 999 }}>{tag}</span>
                </div>
                <div style={{ padding: "8px 9px 9px", fontSize: 9.5, fontWeight: 700, lineHeight: 1.3 }}>{title}</div>
              </div>
            ))}
          </div>
        </div>
        <div style={{ padding: "14px 14px 8px", fontSize: 12, fontWeight: 700 }}>Quick Access</div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, minmax(0, 1fr))", gap: "10px 8px", padding: "0 14px", fontSize: 8, textAlign: "center" }}>
          {qa.map((label) => (
            <span key={label}>
              <span style={{ display: "flex", width: 42, height: 42, margin: "0 auto 4px", borderRadius: 13, background: "#fff", boxShadow: "0 1px 5px rgba(0,0,0,.07)", alignItems: "center", justifyContent: "center" }}>
                <span style={{ width: 16, height: 16, borderRadius: 5, background: "#409843", opacity: 0.85 }} />
              </span>
              {label}
            </span>
          ))}
        </div>
        <div style={{ padding: "16px 14px 8px", fontSize: 12, fontWeight: 700 }}>Priority Agendas</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 9, padding: "0 12px" }}>
          {[["01", "Water & Sanitation", "Clean water access and sanitation for all African communities", "linear-gradient(135deg,#1565C0,#0B3C7A)"], ["02", "A-RISE Initiative", "Innovation, skills and empowerment for youth and women", "linear-gradient(135deg,#B8860B,#4A3E00)"]].map(([n, title, sub, bg]) => (
            <div key={n} style={{ height: 92, borderRadius: 14, overflow: "hidden", background: bg, padding: 11, color: "#fff", display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
              <span style={{ alignSelf: "flex-start", background: "rgba(0,0,0,.3)", color: "#FCD116", fontSize: 7.5, fontWeight: 900, letterSpacing: 0.7, padding: "3px 7px", borderRadius: 999 }}>PRIORITY {n}</span>
              <span><b style={{ display: "block", fontSize: 13, fontWeight: 900 }}>{title}</b><span style={{ fontSize: 8.5, opacity: 0.9 }}>{sub}</span></span>
            </div>
          ))}
        </div>
        <div className="phone-notch" />
      </div>
    </div>
  );
}
