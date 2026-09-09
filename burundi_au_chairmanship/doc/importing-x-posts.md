# Getting X posts into the app, by hand

The automated news scraper was removed (see `core/migrations/0187_remove_news_scraper.py`).
Reading X from the server does not work: gallery-dl's date-bounded search loops
on X's rate limits from a datacenter IP, and a session cookie expires within
days, so an unattended daily fetch was never going to hold.

What does work is running gallery-dl on a **workstation**, against the
operator's own signed-in browser. No datacenter IP, no server-side cookie to
expire, and it only runs when there is something worth importing.

## 1. Scrape, on your own machine

```bash
cd burundi_au_chairmanship/backend
./scrape_x.sh chrome        # or: ./scrape_x.sh firefox
```

Reads your browser's X session and writes JSON + media to `media/x_scrape/`.
Re-running only adds what is new. Never run this in CI or a container — the
script refuses, because those cookies are your real account.

## 2. Preview

```bash
python3 manage.py import_x_posts --dry-run --since 2026-09-01
```

Posts already imported are skipped on title, so re-running is safe. Without
`--since` it goes back to 2025-01-01.

## 3. Import into production

The command writes wherever `DATABASE_URL` points, and uploads images to Spaces
whenever `DJANGO_DEBUG=False`. Both together put the posts on the live site:

```bash
DJANGO_DEBUG=False \
DATABASE_URL='<the connection string from the DO console → Databases>' \
python3 manage.py import_x_posts --since 2026-09-01
```

Drop `DATABASE_URL` to import into the local SQLite database instead.

Two things to know before the first run:

* The managed database's **Trusted Sources** must allow your IP, or the
  connection is refused. DO console → the database → Settings → Trusted Sources.
* `DO_SPACES_*` must be set in `backend/.env`, or `DJANGO_DEBUG=False` will try
  to upload to a bucket it has no keys for. They are already there.

Imported posts become ordinary Articles (and Events or LiveFeeds, by keyword —
see `import_x_posts.py`). Nothing is published behind your back: check them in
the admin the way you would any article.
