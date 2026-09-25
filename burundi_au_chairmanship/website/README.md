# burundi4africa.com — public website

Next.js (App Router) front end for the Embassy of Burundi in Addis Ababa. It renders on the
server from the same Django REST API the B4Africa mobile app uses (`backend/`), so news,
events, magazines, videos, galleries, priority agendas, emergency contacts, missions,
documents and social links are all managed in the existing admin. Only institutional copy
with no model behind it (visa fees, consular procedures, history, hotels) lives in the pages.

Design: the "Tanganyika" direction of the Claude Design canvas (Alegreya + Lato, deep green
and gold on ivory). Shared styles are in `app/globals.css`; page-specific styles sit beside
their page.

## Run locally

```bash
cd burundi_au_chairmanship/website
npm install
npm run dev            # http://localhost:3000, data from the production API
```

Environment (all optional):

| Variable         | Default                           | Purpose                                                                 |
| ---------------- | --------------------------------- | ----------------------------------------------------------------------- |
| `API_BASE`       | `https://burundi4africa.com/api`  | Django API to read from. Use `http://127.0.0.1:8000/api` for local data.  |
| `API_REVALIDATE` | `300`                             | Seconds a fetched API response is cached on the server (ISR).            |
| `BACKEND_ORIGIN` | unset                             | When set, `/api`, `/admin`, `/media`, `/static`, `/app`, share cards… are proxied there. Locally: `http://127.0.0.1:8000`. |
| `SITE_URL`       | `https://burundi4africa.com`      | Canonical origin for metadata, sitemap and robots.                       |

Language: the header toggle hits `/lang/en` or `/lang/fr`, which sets a `lang` cookie.
API fields use the `_fr` variant when present; static copy is translated inline with `t()`.

## Routes

| Path                  | Source of data                                              |
| --------------------- | ----------------------------------------------------------- |
| `/`                   | articles, categories, priority agendas, live feeds, events, settings |
| `/news`, `/news/[id]` | articles (category, search, pagination), videos, magazines, gallery, resources |
| `/events`             | events, event registrations, live feeds                     |
| `/au-2026`            | priority agendas, gallery, live feeds, videos, magazines, resources, settings |
| `/au-2026/priorities` | priority agendas, articles                                  |
| `/media`, `/media/albums/[id]`, `/media/videos/[id]` | live feeds, videos, magazines, gallery, resources, social links |
| `/services`           | static                                                      |
| `/embassy`            | embassy locations (new `/api/embassy-locations/` endpoint)  |
| `/burundi`            | facts, resources                                            |
| `/diaspora`           | embassy locations, social links                             |
| `/travel`             | emergency contacts, embassy locations                       |
| `/invest`             | articles (Economy), resources                               |

`/sitemap.xml` and `/robots.txt` are generated.

## Deploying next to Django

The Django app keeps serving `/api`, `/admin`, `/media`, `/static`, `/app` (store redirect),
`/register`, `/verify`, the legal pages, `/.well-known/*` and the share cards
(`/articles/5/share/`, `/events/7/share/`, `…/card.jpg`). Everything else is this site.

On DigitalOcean App Platform, add the website as a second component of the existing app:

1. **Component**: Web Service, source directory `burundi_au_chairmanship/website`,
   build `npm ci && npm run build`, run `npm run start`, HTTP port 3000, Node 20+.
2. **Routes**: give the website `/`. Keep the backend's routes as explicit prefixes:
   `/api`, `/admin`, `/media`, `/static`, `/app`, `/register`, `/verify`, `/privacy-policy`,
   `/terms-of-service`, `/support`, `/delete-account`, `/.well-known`,
   `/apple-app-site-association`. App Platform picks the longest matching prefix, so these
   keep reaching Django while `/` falls through to the site.
3. **Share cards** live under paths the site also owns (`/events/7/share/`), so set
   `BACKEND_ORIGIN` on the website to the backend component's *private* URL
   (`${backend.PRIVATE_URL}`); `next.config.ts` rewrites those two patterns to it. Add that
   private hostname to the backend's `DJANGO_ALLOWED_HOSTS`.
4. Set `SITE_URL=https://burundi4africa.com`. `API_BASE` can stay on the public domain or
   use the private URL as well.

The old landing page (`backend/templates/landing.html`) is still reachable at `/get-the-app`
only if you route that prefix to the backend; otherwise the app promo on every page and
`/app` cover it.

## Checks

```bash
npm run lint
npx tsc --noEmit
npm run build
```
