import Link from "next/link";
import { getLang, t } from "@/lib/i18n";

export default async function NotFound() {
  const lang = await getLang();
  return (
    <section className="sec">
      <div className="wrap stack">
        <span className="eyebrow">404</span>
        <h1 className="h1 h1--md">{t(lang, "This page does not exist.", "Cette page n’existe pas.")}</h1>
        <p className="lede">{t(lang, "The address may have changed when the site was redesigned.", "L’adresse a peut-être changé lors de la refonte du site.")}</p>
        <div><Link className="btn" href="/">{t(lang, "Back to the homepage", "Retour à l’accueil")}</Link></div>
      </div>
    </section>
  );
}
