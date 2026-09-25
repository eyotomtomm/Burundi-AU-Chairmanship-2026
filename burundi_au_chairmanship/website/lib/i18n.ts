import { cookies } from "next/headers";
import type { Lang } from "./types";

export const LANG_COOKIE = "lang";

export async function getLang(): Promise<Lang> {
  const c = await cookies();
  return c.get(LANG_COOKIE)?.value === "fr" ? "fr" : "en";
}

/** Inline copy: t(lang, "English", "Français"). */
export const t = (lang: Lang, en: string, fr: string) => (lang === "fr" && fr ? fr : en);

/** Bilingual API field: tr(article, "title", lang) → title_fr on a French page when filled. */
export function tr<T extends object>(obj: T | null | undefined, field: string, lang: Lang): string {
  if (!obj) return "";
  const o = obj as Record<string, unknown>;
  if (lang === "fr") {
    const fr = o[`${field}_fr`];
    if (typeof fr === "string" && fr.trim()) return fr;
  }
  const en = o[field] ?? o[`${field}_en`];
  return typeof en === "string" ? en : "";
}

export function fmtDate(iso: string | null | undefined, lang: Lang, opts: Intl.DateTimeFormatOptions = {}) {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return new Intl.DateTimeFormat(lang === "fr" ? "fr-FR" : "en-GB", {
    day: "numeric", month: "long", year: "numeric", timeZone: "Africa/Addis_Ababa", ...opts,
  }).format(d);
}

export function fmtTime(iso: string | null | undefined, lang: Lang) {
  return fmtDate(iso, lang, { day: undefined, month: undefined, year: undefined, hour: "2-digit", minute: "2-digit" });
}

/** Plain-text article bodies: blank-line paragraphs, "•"/"-" bullet runs. */
export function paragraphs(text: string): Array<{ type: "p" | "ul"; lines: string[] }> {
  return (text ?? "")
    .replace(/\r/g, "")
    .split(/\n\s*\n/)
    .map((b) => b.split("\n").map((l) => l.trim()).filter(Boolean))
    .filter((lines) => lines.length)
    .map((lines) =>
      lines.every((l) => /^[•\-–]/.test(l))
        ? { type: "ul" as const, lines: lines.map((l) => l.replace(/^[•\-–]\s*/, "")) }
        : { type: "p" as const, lines },
    );
}

export function excerpt(text: string, words = 32) {
  const w = (text ?? "").replace(/\s+/g, " ").trim().split(" ");
  return w.length > words ? w.slice(0, words).join(" ") + "…" : w.join(" ");
}
