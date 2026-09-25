import type { Lang } from "@/lib/types";
import { t } from "@/lib/i18n";

export interface NavChild { href: string; label: string; hint?: string }
export interface NavGroup { href: string; label: string; children: NavChild[] }

/** One source for the desktop dropdowns, the phone menu and the footer. Every href is a real route or anchor. */
export function navGroups(lang: Lang): NavGroup[] {
  return [
    { href: "/", label: t(lang, "Home", "Accueil"), children: [] },
    {
      href: "/services", label: "Services",
      children: [
        { href: "/services#visa", label: "Visa", hint: t(lang, "Types, fees and requirements", "Types, tarifs et pièces") },
        { href: "/services#passport", label: t(lang, "Passport", "Passeport"), hint: t(lang, "Ordinary, service, diplomatic", "Ordinaire, de service, diplomatique") },
        { href: "/services#laissez-passer", label: t(lang, "Laissez-passer & CEPGL card", "Laissez-passer & carte CEPGL") },
        { href: "/services#other", label: t(lang, "Other services", "Autres services"), hint: t(lang, "Legalisation, civil status, certificates", "Légalisation, état civil, attestations") },
      ],
    },
    {
      href: "/embassy", label: t(lang, "Embassy", "L’Ambassade"),
      children: [
        { href: "/embassy", label: t(lang, "The Embassy", "L’Ambassade"), hint: t(lang, "Mission and mandates", "Mission et mandats") },
        { href: "/embassy#message", label: t(lang, "Ambassador’s message", "Le mot de l’Ambassadeur") },
        { href: "/embassy#team", label: t(lang, "Embassy staff", "L’équipe") },
        { href: "/embassy#contact", label: t(lang, "Hours & contact", "Horaires & contact") },
        { href: "/embassy#missions", label: t(lang, "Other Burundian missions", "Autres missions du Burundi") },
      ],
    },
    {
      href: "/burundi", label: "Burundi",
      children: [
        { href: "/burundi", label: t(lang, "Discover Burundi", "Découvrir le Burundi"), hint: t(lang, "Geography, history, culture", "Géographie, histoire, culture") },
        { href: "/burundi#places", label: t(lang, "Places to see", "À voir") },
        { href: "/travel", label: t(lang, "Travel & emergency", "Voyage & urgences"), hint: t(lang, "Checklist, phrasebook, SOS", "Check-list, lexique, SOS") },
        { href: "/invest", label: t(lang, "Invest in Burundi", "Investir au Burundi") },
      ],
    },
    {
      href: "/diaspora", label: "Diaspora",
      children: [
        { href: "/diaspora#register", label: t(lang, "Join the diaspora database", "Rejoindre la base diaspora") },
        { href: "/diaspora#policy", label: t(lang, "National diaspora policy", "Politique nationale de la diaspora") },
        { href: "/diaspora#missions", label: t(lang, "Missions near you", "Missions près de chez vous") },
        { href: "/travel#emergency", label: t(lang, "Emergency assistance", "Assistance d’urgence") },
      ],
    },
    {
      href: "/au-2026", label: "AU 2026",
      children: [
        { href: "/au-2026", label: t(lang, "The chairmanship", "La présidence"), hint: t(lang, "Burundi at the head of the Union", "Le Burundi à la tête de l’Union") },
        { href: "/au-2026/priorities", label: t(lang, "Priority agenda", "Agenda prioritaire"), hint: t(lang, "Water, A-RISE, peace & security", "Eau, A-RISE, paix & sécurité") },
        { href: "/events", label: t(lang, "Events & Continental Dialogue", "Événements & Dialogue continental") },
        { href: "/au-2026#watch", label: t(lang, "Watch and follow", "Regarder et suivre") },
      ],
    },
    {
      href: "/news", label: t(lang, "Newsroom", "Actualités"),
      children: [
        { href: "/news", label: t(lang, "All news", "Toutes les actualités") },
        { href: "/events", label: t(lang, "Events", "Événements") },
        { href: "/media", label: t(lang, "Media centre", "Médiathèque"), hint: t(lang, "Videos, magazine, albums", "Vidéos, magazine, albums") },
        { href: "/media#documents", label: t(lang, "Documents", "Documents") },
      ],
    },
  ];
}
