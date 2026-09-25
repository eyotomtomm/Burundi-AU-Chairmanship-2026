import type { MetadataRoute } from "next";
import { api } from "@/lib/api";

const SITE = process.env.SITE_URL ?? "https://burundi4africa.com";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const staticPaths = ["", "/services", "/embassy", "/burundi", "/diaspora", "/travel", "/invest",
    "/au-2026", "/au-2026/priorities", "/events", "/news", "/media-centre"];
  const [news, albums] = await Promise.all([api.articles({ page_size: 200 }), api.albums()]);
  return [
    ...staticPaths.map((p) => ({ url: `${SITE}${p}`, changeFrequency: "weekly" as const, priority: p === "" ? 1 : 0.7 })),
    ...news.results.map((a) => ({ url: `${SITE}/news/${a.id}`, lastModified: a.publish_date, changeFrequency: "monthly" as const, priority: 0.6 })),
    ...albums.results.map((g) => ({ url: `${SITE}/media-centre/albums/${g.id}`, lastModified: g.created_at, changeFrequency: "monthly" as const, priority: 0.4 })),
  ];
}
