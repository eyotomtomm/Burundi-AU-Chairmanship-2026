import "server-only";
import type {
  AppSettings, Article, Category, EmbassyLocation, EmergencyContact, Event, EventRegistration,
  Fact, GalleryAlbum, LiveFeed, Magazine, Paginated, PriorityAgenda, Resource, SocialLink, Video, ChairshipPost,
} from "./types";

// The Django API the mobile app already uses. Rendered on the server and revalidated,
// so the anonymous rate limit (100/hour) is never a concern for visitors.
export const API_BASE = (process.env.API_BASE ?? "https://burundi4africa.com/api").replace(/\/$/, "");
const REVALIDATE = Number(process.env.API_REVALIDATE ?? 300);

async function get<T>(path: string, fallback: T): Promise<T> {
  const url = `${API_BASE}/${path.replace(/^\//, "")}`;
  try {
    const res = await fetch(url, {
      headers: {
        Accept: "application/json",
        "User-Agent": "burundi4africa-web/1.0",
        // Exempts this server from the API's anonymous rate limit (core/throttling.py); unset locally is fine.
        ...(process.env.SITE_API_KEY ? { "X-Site-Key": process.env.SITE_API_KEY } : {}),
      },
      next: { revalidate: REVALIDATE },
    });
    if (!res.ok) {
      console.warn(`[api] ${res.status} ${url}`);
      return fallback;
    }
    return (await res.json()) as T;
  } catch (err) {
    console.warn(`[api] failed ${url}`, err);
    return fallback;
  }
}

const empty = <T,>(): Paginated<T> => ({ count: 0, next: null, previous: null, results: [] });

export const api = {
  settings: () => get<AppSettings | null>("settings/", null),
  categories: () => get<Category[]>("categories/", []),
  social: () => get<SocialLink[]>("social-media/", []),
  agendas: () => get<PriorityAgenda[]>("priority-agendas/", []),
  embassies: () => get<EmbassyLocation[]>("embassy-locations/", []),
  emergency: async () => (await get<Paginated<EmergencyContact>>("emergency-contacts/?page_size=100", empty())).results,

  /** The articles endpoint returns the whole public list in one response (the app paginates
   *  locally), so `page` and `page_size` are applied here after the fetch; one cached fetch serves every page. */
  articles: async (params: Record<string, string | number | undefined> = {}) => {
    const { page = 1, page_size = 12, ...rest } = params;
    const data = await get<Paginated<Article>>(`articles/?${qs({ ordering: "-publish_date", ...rest })}`, empty());
    const size = Number(page_size) || 12;
    const p = Math.max(1, Number(page) || 1);
    const all = data.results.length > data.count ? data.results : data.results;
    const count = data.next ? data.count : all.length;
    const results = all.slice((p - 1) * size, p * size);
    const pages = Math.max(1, Math.ceil(count / size));
    return { count, results, next: p < pages ? String(p + 1) : null, previous: p > 1 ? String(p - 1) : null } as Paginated<Article>;
  },
  article: (id: string | number) => get<Article | null>(`articles/${id}/`, null),
  /** Full-text search (title + content, both languages); max 20 results, no pagination. */
  searchArticles: async (q: string) => (await get<{ results: Article[]; count: number }>(`search/articles/?q=${encodeURIComponent(q)}`, { results: [], count: 0 })).results,

  events: (params: Record<string, string | number | undefined> = {}) =>
    get<Paginated<Event>>(`events/?${qs({ page_size: 50, ...params })}`, empty()),
  registrations: () => get<Paginated<EventRegistration>>("event-registrations/?page_size=20", empty()),
  live: () => get<Paginated<LiveFeed>>("live-feeds/?page_size=20", empty()),

  magazines: () => get<Paginated<Magazine>>("magazines/?page_size=50", empty()),
  albums: () => get<Paginated<GalleryAlbum>>("gallery/?page_size=50", empty()),
  album: (id: string | number) => get<GalleryAlbum | null>(`gallery/${id}/`, null),
  videos: (params: Record<string, string | number | undefined> = {}) =>
    get<Paginated<Video>>(`videos/?${qs({ page_size: 50, ...params })}`, empty()),
  resources: () => get<Paginated<Resource>>("resources/?page_size=100", empty()),
  facts: () => get<Paginated<Fact>>("facts/?page_size=50", empty()),
};

function qs(params: Record<string, string | number | undefined>) {
  return Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== "")
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
    .join("&");
}

/** Absolute media URL: the API returns absolute Spaces URLs in production and /media/... locally. */
export function media(url: string | null | undefined): string {
  if (!url) return "";
  if (/^https?:\/\//.test(url)) return url;
  return `${API_BASE.replace(/\/api$/, "")}${url}`;
}

export function youtubeId(url: string): string {
  const m = /(?:youtu\.be\/|v=|\/embed\/|\/shorts\/)([A-Za-z0-9_-]{11})/.exec(url ?? "");
  return m ? m[1] : "";
}

// burundichairship.africa is the chairmanship's WordPress site; its posts are shown alongside the
// Embassy's own newsroom. Read through the public WP REST API, cached for half an hour.
const CHAIRSHIP = "https://burundichairship.africa";

function stripHtml(html: string) {
  return (html ?? "").replace(/<[^>]+>/g, " ").replace(/&hellip;|\[&hellip;\]/g, "…").replace(/&#8217;|&rsquo;/g, "’")
    .replace(/&#8220;|&#8221;/g, "\"").replace(/&amp;/g, "&").replace(/&nbsp;/g, " ").replace(/\s+/g, " ").trim();
}

export async function chairshipPosts(limit = 6): Promise<ChairshipPost[]> {
  const url = `${CHAIRSHIP}/wp-json/wp/v2/posts?per_page=${limit}&_embed=wp:featuredmedia,wp:term&_fields=id,date,link,title,excerpt,_links,_embedded`;
  try {
    const res = await fetch(url, { headers: { Accept: "application/json", "User-Agent": "burundi4africa-web/1.0" }, next: { revalidate: 1800 } });
    if (!res.ok) return [];
    type WpPost = {
      id: number; date: string; link: string; title: { rendered: string }; excerpt: { rendered: string };
      _embedded?: { "wp:featuredmedia"?: Array<{ source_url?: string; media_details?: { sizes?: Record<string, { source_url: string }> } }>; "wp:term"?: Array<Array<{ name: string; taxonomy: string }>> };
    };
    const posts = (await res.json()) as WpPost[];
    return posts.map((p) => {
      const fm = p._embedded?.["wp:featuredmedia"]?.[0];
      const sizes = fm?.media_details?.sizes ?? {};
      return {
        id: p.id, date: p.date, link: p.link,
        title: stripHtml(p.title.rendered), excerpt: stripHtml(p.excerpt.rendered),
        image: sizes.medium_large?.source_url ?? sizes.large?.source_url ?? fm?.source_url ?? null,
        categories: (p._embedded?.["wp:term"] ?? []).flat().filter((t) => t.taxonomy === "category").map((t) => stripHtml(t.name)),
      };
    });
  } catch (err) {
    console.warn("[api] chairship posts failed", err);
    return [];
  }
}
