import type { MetadataRoute } from "next";

const SITE = process.env.SITE_URL ?? "https://burundi4africa.com";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/", disallow: ["/admin/", "/api/", "/lang/"] },
    sitemap: `${SITE}/sitemap.xml`,
  };
}
