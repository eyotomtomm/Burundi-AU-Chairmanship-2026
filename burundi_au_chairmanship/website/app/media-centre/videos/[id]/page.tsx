import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { api, media, youtubeId } from "@/lib/api";
import { fmtDate, getLang, paragraphs, t, tr } from "@/lib/i18n";
import { Crumbs } from "@/components/ui";
import { categoryLabel } from "../../videos";
import s from "../../media.module.css";

type Props = { params: Promise<{ id: string }> };

async function load(id: string) {
  const all = await api.videos({ page_size: 100 });
  const sorted = [...all.results].sort((a, b) => b.publish_date.localeCompare(a.publish_date));
  return { video: sorted.find((v) => String(v.id) === id) ?? null, more: sorted.filter((v) => String(v.id) !== id).slice(0, 3) };
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const { video } = await load(id);
  if (!video) return { title: "Video" };
  return { title: video.title, description: video.description || undefined, openGraph: { images: [media(video.thumbnail_url || video.thumbnail)] } };
}

export default async function VideoPage({ params }: Props) {
  const { id } = await params;
  const [lang, { video, more }] = await Promise.all([getLang(), load(id)]);
  if (!video) notFound();
  const yt = youtubeId(video.video_url);

  return (
    <>
      <section className="sec--dark" style={{ padding: "48px 0 72px" }}>
        <div className="wrap stack">
          <div style={{ color: "var(--mint-2)" }}><Crumbs lang={lang} items={[[t(lang, "Media centre", "Médiathèque"), "/media-centre"], [t(lang, "Videos", "Vidéos"), "/media-centre#videos"], [tr(video, "title", lang)]]} /></div>
          <div className="embed">
            {yt ? (
              <iframe src={`https://www.youtube-nocookie.com/embed/${yt}`} title={tr(video, "title", lang)} allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowFullScreen />
            ) : video.video_url ? (
              <video controls preload="metadata" poster={media(video.thumbnail_url || video.thumbnail) || undefined} style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}>
                <source src={media(video.video_url)} />
              </video>
            ) : (
              <img src={media(video.thumbnail_url || video.thumbnail) || "/img/drummers.jpg"} alt="" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover" }} />
            )}
          </div>
          <div className="grid" style={{ alignItems: "start" }}>
            <div className="span-8 stack" style={{ gap: 12 }}>
              <span className="sc" style={{ fontSize: 15, color: "var(--gold)" }}>{categoryLabel(video.category, lang)} · {fmtDate(video.publish_date, lang)}{video.duration ? ` · ${video.duration}` : ""}</span>
              <h1 className="h2" style={{ color: "#fff" }}>{tr(video, "title", lang)}</h1>
            </div>
            {!yt && video.video_url && (
              <a className="span-4 btn btn--gold btn--md" href={video.video_url} rel="noopener" style={{ justifySelf: "end" }}>{t(lang, "Open the video", "Ouvrir la vidéo")}</a>
            )}
          </div>
        </div>
      </section>

      <section className="sec">
        <div className="wrap grid" style={{ alignItems: "start" }}>
          <div className="span-7 prose">
            {paragraphs(tr(video, "description", lang)).map((b, i) =>
              b.type === "ul" ? <ul key={i}>{b.lines.map((l, j) => <li key={j}>{l}</li>)}</ul> : <p key={i}>{b.lines.join(" ")}</p>,
            )}
          </div>
          <aside className="span-4 start-9 stack" style={{ gap: 14 }}>
            <span className="eyebrow">{t(lang, "More videos", "Plus de vidéos")}</span>
            <ol className={s.upnext} style={{ borderTopColor: "var(--ink)" }}>
              {more.map((v) => (
                <li key={v.id}>
                  <Link href={`/media-centre/videos/${v.id}`} style={{ borderBottomColor: "var(--line-2)" }}>
                    <span className={s.thumb}>
                      <img src={media(v.medium_url || v.thumbnail) || "/img/karera-falls.jpg"} alt="" loading="lazy" />
                      {v.duration && <span className={s.dur}>{v.duration}</span>}
                    </span>
                    <span className="stack" style={{ gap: 4 }}>
                      <span className="num small">{categoryLabel(v.category, lang)}</span>
                      <span style={{ fontFamily: "var(--display)", fontSize: 20, lineHeight: 1.25 }}>{tr(v, "title", lang)}</span>
                    </span>
                  </Link>
                </li>
              ))}
            </ol>
            <Link className="more arrow" href="/media-centre#videos">{t(lang, "All videos", "Toutes les vidéos")}</Link>
          </aside>
        </div>
      </section>
    </>
  );
}
