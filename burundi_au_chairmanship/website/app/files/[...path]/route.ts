import { MEDIA_STORE } from "@/lib/api";

/** /files/resources/x.pdf — serves documents from the media store under our own domain,
 *  so the storage bucket's address never shows in the browser. */
const FOLDERS = new Set(["resources", "magazines"]);

export async function GET(req: Request, ctx: { params: Promise<{ path: string[] }> }) {
  const { path } = await ctx.params;
  if (!FOLDERS.has(path[0]) || path.some((p) => p === ".." || p === ".")) return new Response("Not found", { status: 404 });
  const headers = new Headers();
  const range = req.headers.get("range");
  if (range) headers.set("range", range);
  const res = await fetch(`${MEDIA_STORE}/${path.map(encodeURIComponent).join("/")}`, { headers, cache: "no-store" });
  if (!res.ok || !res.body) return new Response("Not found", { status: 404 });
  const out = new Headers({ "content-disposition": "inline", "cache-control": "public, max-age=86400" });
  for (const h of ["content-type", "content-length", "content-range", "accept-ranges", "etag", "last-modified"]) {
    const v = res.headers.get(h);
    if (v) out.set(h, v);
  }
  return new Response(res.body, { status: res.status, headers: out });
}
