import "server-only";
import { notFound } from "next/navigation";

const KINDS = new Set(["articles", "magazines", "events", "facts", "videos", "gallery", "features", "agendas", "discussions"]);

/** Forwards a request to Django over the platform's private network, keeping the public host and
 *  scheme so Django's ALLOWED_HOSTS and https redirect see the original request. */
export async function proxyToBackend(req: Request, path: string): Promise<Response> {
  const origin = process.env.BACKEND_ORIGIN?.replace(/\/$/, "");
  const kind = path.split("/")[1];
  if (!origin || !KINDS.has(kind)) notFound();
  const incoming = new URL(req.url);
  const target = `${origin}${path}${incoming.search}`;
  const headers = new Headers();
  for (const h of ["user-agent", "accept", "accept-language", "cookie", "referer", "cf-connecting-ip", "x-forwarded-for"]) {
    const v = req.headers.get(h);
    if (v) headers.set(h, v);
  }
  const publicHost = process.env.SITE_URL ? new URL(process.env.SITE_URL).host : incoming.host;
  headers.set("x-forwarded-host", publicHost);
  headers.set("x-forwarded-proto", "https");
  const res = await fetch(target, { headers, redirect: "manual", cache: "no-store" });
  const out = new Headers();
  for (const h of ["content-type", "cache-control", "location", "vary", "content-language"]) {
    const v = res.headers.get(h);
    if (v) out.set(h, v);
  }
  return new Response(res.body, { status: res.status, headers: out });
}
