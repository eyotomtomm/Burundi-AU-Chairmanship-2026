import type { Lang, Video } from "@/lib/types";
import { t } from "@/lib/i18n";

export const VIDEO_CATEGORIES: Array<[Video["category"], string, string]> = [
  ["highlight", "Highlights", "Temps forts"],
  ["speech", "Speeches", "Discours"],
  ["documentary", "Documentaries", "Documentaires"],
  ["interview", "Interviews", "Entretiens"],
  ["event", "Events", "Événements"],
  ["cultural", "Cultural", "Culture"],
];
export const categoryLabel = (c: Video["category"], lang: Lang) => {
  const row = VIDEO_CATEGORIES.find(([k]) => k === c);
  return row ? t(lang, row[1], row[2]) : c;
};
