import { NextResponse, type NextRequest } from "next/server";
import { LANG_COOKIE } from "@/lib/i18n";

/** /lang/fr?next=/news → sets the language cookie and returns to the page. */
export async function GET(req: NextRequest, { params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  const next = req.nextUrl.searchParams.get("next") ?? "/";
  const safe = next.startsWith("/") && !next.startsWith("//") ? next : "/";
  const res = NextResponse.redirect(new URL(safe, req.url));
  res.cookies.set(LANG_COOKIE, code === "fr" ? "fr" : "en", { path: "/", maxAge: 365 * 86400, sameSite: "lax" });
  return res;
}
