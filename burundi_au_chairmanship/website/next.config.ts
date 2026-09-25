import type { NextConfig } from "next";

// Paths that belong to Django, not to this site. In production the platform
// routes these prefixes straight to the backend; the rewrites below cover the
// prefixes for local development against one origin. Share cards (/events/7/share/,
// /articles/5/card.jpg) are served by app/[kind]/[pk]/* route handlers, which proxy to
// BACKEND_ORIGIN with the public host and https scheme preserved.
// BACKEND_ORIGIN must be the backend's *private* URL in production — pointing
// it at the public domain would loop back into this site.
const DJANGO_PREFIXES = [
  "api", "admin", "media", "static", "app", "register", "verify",
  "privacy-policy", "terms-of-service", "support", "delete-account",
  ".well-known", "apple-app-site-association",
];

const nextConfig: NextConfig = {
  // Media lives on DigitalOcean Spaces behind a CDN; plain <img> is enough.
  images: { unoptimized: true },
  async rewrites() {
    const backend = process.env.BACKEND_ORIGIN?.replace(/\/$/, "");
    if (!backend) return [];
    return [
      ...DJANGO_PREFIXES.flatMap((p) => [
        { source: `/${p}`, destination: `${backend}/${p}` },
        { source: `/${p}/:path*`, destination: `${backend}/${p}/:path*` },
      ]),
    ];
  },
};

export default nextConfig;
