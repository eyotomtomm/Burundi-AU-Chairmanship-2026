import type { Metadata } from "next";
import { Alegreya, Alegreya_SC, Lato, Smooch_Sans } from "next/font/google";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { AppPromo } from "@/components/AppPromo";
import { getLang } from "@/lib/i18n";
import { api } from "@/lib/api";
import "./globals.css";

const display = Alegreya({ variable: "--font-display", subsets: ["latin"], weight: ["500", "700"], style: ["normal", "italic"] });
const sc = Alegreya_SC({ variable: "--font-sc", subsets: ["latin"], weight: ["500", "700"] });
const body = Lato({ variable: "--font-body", subsets: ["latin"], weight: ["400", "700"] });
const band = Smooch_Sans({ variable: "--font-band", subsets: ["latin"], weight: ["800", "900"] });

export const metadata: Metadata = {
  metadataBase: new URL(process.env.SITE_URL ?? "https://burundi4africa.com"),
  title: { default: "Embassy of Burundi in Addis Ababa", template: "%s · Embassy of Burundi in Addis Ababa" },
  description:
    "The Embassy of the Republic of Burundi in Addis Ababa and its Permanent Mission to the African Union. Consular services, news and support for Burundians and visitors.",
  icons: { icon: "/img/seal.png" },
  openGraph: { siteName: "Embassy of Burundi in Addis Ababa", images: ["/img/au-hq.jpg"], type: "website" },
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const lang = await getLang();
  const [settings, social] = await Promise.all([api.settings(), api.social()]);
  return (
    <html lang={lang} className={`${display.variable} ${sc.variable} ${body.variable} ${band.variable}`}>
      <body>
        <Header lang={lang} />
        <main id="main">{children}</main>
        <AppPromo lang={lang} settings={settings} />
        <Footer lang={lang} settings={settings} social={social} />
        {/* A photo that fails to load hides itself, leaving the card's own background instead of a broken-image icon. */}
        <script dangerouslySetInnerHTML={{ __html: "addEventListener('error',function(e){var t=e.target;if(t&&t.tagName==='IMG'){t.style.visibility='hidden'}},true)" }} />
      </body>
    </html>
  );
}
