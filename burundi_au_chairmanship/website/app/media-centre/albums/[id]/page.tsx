import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { api, media } from "@/lib/api";
import { fmtDate, getLang, t, tr } from "@/lib/i18n";
import { Crumbs } from "@/components/ui";
import s from "../../media.module.css";

type Props = { params: Promise<{ id: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const album = await api.album(id);
  if (!album) return { title: "Album" };
  return { title: album.title, description: album.description || undefined, openGraph: { images: [media(album.cover_image)] } };
}

export default async function AlbumPage({ params }: Props) {
  const { id } = await params;
  const [lang, album] = await Promise.all([getLang(), api.album(id)]);
  if (!album) notFound();
  const photos = [...album.photos].sort((a, b) => a.id - b.id);

  return (
    <>
      <section className="page-hero sec--ivory">
        <div className="wrap stack" style={{ gap: 20 }}>
          <Crumbs lang={lang} items={[[t(lang, "Media centre", "Médiathèque"), "/media-centre"], [t(lang, "Albums", "Albums"), "/media-centre#albums"], [tr(album, "title", lang)]]} />
          <span className="eyebrow">{t(lang, "Photo album", "Album photo")} · {fmtDate(album.created_at, lang)}</span>
          <h1 className="h1">{tr(album, "title", lang)}</h1>
          {tr(album, "description", lang) && <p className="lede">{tr(album, "description", lang)}</p>}
          <span className={s.count} style={{ alignSelf: "flex-start" }}>{album.photo_count} {t(lang, "photos", "photos")}</span>
        </div>
      </section>
      <section className="sec">
        <div className="wrap stack stack--lg">
          <div className={s.photos}>
            {photos.map((p) => (
              <figure key={p.id} className={s.photo}>
                <a href={media(p.image)} rel="noopener"><img src={media(p.medium_url || p.image)} alt={tr(p, "caption", lang) || tr(album, "title", lang)} loading="lazy" /></a>
                {(tr(p, "caption", lang) || p.photographer || p.taken_date) && (
                  <figcaption className="small muted">
                    {tr(p, "caption", lang)}
                    {p.photographer && <> · © {p.photographer}</>}
                    {p.taken_date && <> · {fmtDate(p.taken_date, lang)}</>}
                  </figcaption>
                )}
              </figure>
            ))}
          </div>
          <div><Link className="btn btn--outline btn--md" href="/media-centre#albums">{t(lang, "All albums", "Tous les albums")}</Link></div>
        </div>
      </section>
    </>
  );
}
