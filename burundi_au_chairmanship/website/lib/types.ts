// Shapes of the Django REST API at /api/ (see backend/core/serializers.py).

export type Lang = "en" | "fr";

export interface Paginated<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export interface Category {
  id: number;
  name: string;
  name_fr: string;
  color: string;
  order: number;
}

export interface ArticleMedia {
  id: number;
  media_type: "image" | "video";
  image: string | null;
  video_url: string;
  caption: string;
  caption_fr: string;
  order: number;
}

export interface Article {
  id: number;
  title: string;
  title_fr: string;
  image: string | null;
  thumbnail_url: string | null;
  medium_url: string | null;
  author: string;
  category: Category | null;
  publish_date: string;
  content_type: "article" | "news";
  is_featured: boolean;
  view_count: number;
  comment_count: number;
  like_count: number;
  media: ArticleMedia[];
  content: string;
  content_fr: string;
}

export interface Event {
  id: number;
  name: string;
  name_fr: string;
  description: string;
  description_fr: string;
  address: string;
  map_url: string;
  event_date: string;
  image: string | null;
  thumbnail_url: string | null;
  medium_url: string | null;
  recurrence_type: string;
  recurrence_end_date: string | null;
}

export interface EventRegistration {
  id: number;
  card_type: string;
  event_type: "in_person" | "online" | "hybrid";
  category: { id: number; name: string; name_fr: string; color: string } | null;
  event_title: string;
  event_title_fr: string;
  event_description: string;
  event_description_fr: string;
  event_poster: string | null;
  event_date: string | null;
  event_end_date: string | null;
  venue: string;
  venue_fr: string;
  venue_address: string;
  is_registration_enabled: boolean;
  registration_deadline: string | null;
  max_registrations: number;
}

export interface LiveFeed {
  id: number;
  title: string;
  title_fr: string;
  description: string;
  description_fr: string;
  event: number | null;
  event_name: string | null;
  event_date: string | null;
  stream_url: string;
  stream_type: string;
  thumbnail: string | null;
  status: "upcoming" | "live" | "recorded" | "ended";
  viewer_count: number;
  duration: string;
  scheduled_time: string | null;
}

export interface Magazine {
  id: number;
  title: string;
  title_fr: string;
  description: string;
  description_fr: string;
  cover_image: string;
  thumbnail_url: string | null;
  medium_url: string | null;
  pdf_file: string | null;
  external_url: string;
  effective_pdf_url: string | null;
  publish_date: string;
  is_featured: boolean;
  page_count: number;
  file_size: string;
}

export interface GalleryPhoto {
  id: number;
  image: string;
  thumbnail_url: string | null;
  medium_url: string | null;
  caption: string;
  caption_fr: string;
  photographer: string;
  taken_date: string | null;
}

export interface GalleryAlbum {
  id: number;
  title: string;
  title_fr: string;
  description: string;
  description_fr: string;
  cover_image: string;
  photo_count: number;
  created_at: string;
  is_featured: boolean;
  photos: GalleryPhoto[];
}

export interface Video {
  id: number;
  title: string;
  title_fr: string;
  description: string;
  description_fr: string;
  video_url: string;
  thumbnail: string | null;
  thumbnail_url: string | null;
  medium_url: string | null;
  duration: string;
  category: "highlight" | "speech" | "documentary" | "interview" | "event" | "cultural";
  publish_date: string;
  is_featured: boolean;
}

export interface ImpactArea {
  icon: string;
  title: string;
  description: string;
}

export interface PriorityAgenda {
  id: number;
  title: string;
  title_fr: string;
  slug: string;
  description: string;
  description_fr: string;
  overview: string;
  overview_fr: string;
  objectives: string[];
  objectives_fr: string[];
  impact_areas: ImpactArea[];
  impact_areas_fr: ImpactArea[];
  current_initiatives: string;
  current_initiatives_fr: string;
  icon_name: string;
  display_order: number;
  hero_image: string | null;
}

export interface Resource {
  id: number;
  title: string;
  title_fr: string;
  category: "official_documents" | "country_info" | "media" | "reference";
  file: string;
  file_size: string;
  file_type: string;
  created_at: string;
}

export interface EmergencyContact {
  id: number;
  name_en: string;
  name_fr: string;
  description_en: string;
  description_fr: string;
  category: "police" | "fire" | "medical" | "support" | "other";
  action_type: "call" | "whatsapp" | "sms" | "email" | "url" | "route";
  contact_value: string;
  color: string;
  order: number;
}

export interface SocialLink {
  id: number;
  platform: string;
  display_name: string;
  display_name_fr: string;
  url: string;
  handle: string;
  follower_count: string;
  display_order: number;
}

export interface EmbassyLocation {
  id: number;
  name: string;
  name_fr: string;
  address: string;
  city: string;
  country: string;
  latitude: number;
  longitude: number;
  phone_number: string;
  email: string;
  website: string;
  opening_hours: string;
  type: "embassy" | "consulate" | "event_venue" | "office";
  image: string | null;
}

export interface Fact {
  id: number;
  title: string;
  title_fr: string;
  content_preview: string;
  content_preview_fr: string;
  category: { id: number; name: string; name_fr: string; color: string } | null;
  fact_type: "fact" | "quote";
  source: string;
  source_fr: string;
  author_name: string;
  author_title: string;
  author_title_fr: string;
  image: string | null;
}

export interface AppSettings {
  summit_year: string;
  summit_theme: string;
  summit_theme_fr: string;
  app_store_url: string;
  play_store_url: string;
  live_feeds_enabled: boolean;
  contact_email?: string;
}

/** A post from burundichairship.africa (WordPress REST API). */
export interface ChairshipPost {
  id: number;
  date: string;
  link: string;
  title: string;
  excerpt: string;
  image: string | null;
  categories: string[];
}
