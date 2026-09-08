-- Read-only. What is actually tagged what, and on what evidence.
--
--   psql "$DATABASE_URL" -f doc/audit-content-tags.sql
--
-- Article.content_type defaults to 'article' and the admin form preselects it,
-- so anything an editor did not consciously switch landed there. This reports
-- the shape of that bucket so a retag can be based on evidence rather than a
-- guess.

\pset pager off

\echo '================================================'
\echo ' 1. The whole table, by type and status'
\echo '================================================'
SELECT content_type, status, is_draft, count(*) AS n
FROM   core_article
GROUP  BY content_type, status, is_draft
ORDER  BY content_type, status, is_draft;

\echo ''
\echo '================================================'
\echo ' 2. What the app will show after the deploy'
\echo '================================================'
SELECT 'News tab (content_type=news)'      AS surface, count(*) AS visible
FROM   core_article
WHERE  content_type = 'news' AND status = 'published' AND is_draft = false
  AND  (scheduled_publish_at IS NULL OR scheduled_publish_at <= now())
  AND  (expires_at IS NULL OR expires_at >= now())
UNION ALL
SELECT 'Articles screen (content_type=article)', count(*)
FROM   core_article
WHERE  content_type = 'article' AND status = 'published' AND is_draft = false
  AND  (scheduled_publish_at IS NULL OR scheduled_publish_at <= now())
  AND  (expires_at IS NULL OR expires_at >= now())
UNION ALL
SELECT 'Hidden by the status fix (was public, now not)', count(*)
FROM   core_article
WHERE  is_draft = false AND status <> 'published';

\echo ''
\echo '================================================'
\echo ' 3. The article-tagged bucket, by author'
\echo '    A scraper writes one author string over and over.'
\echo '================================================'
SELECT author, count(*) AS n,
       round(avg(length(content))) AS avg_body_chars
FROM   core_article
WHERE  content_type = 'article'
GROUP  BY author
ORDER  BY n DESC
LIMIT  15;

\echo ''
\echo '================================================'
\echo ' 4. The article-tagged bucket, by body length'
\echo '    News runs short; long-form runs long.'
\echo '================================================'
SELECT CASE
         WHEN length(content) <  1500 THEN 'a. under 1.5k  (reads as news)'
         WHEN length(content) <  4000 THEN 'b. 1.5k - 4k   (either)'
         ELSE                              'c. over 4k     (reads as long-form)'
       END AS body_size, count(*) AS n
FROM   core_article
WHERE  content_type = 'article'
GROUP  BY 1 ORDER BY 1;

\echo ''
\echo '================================================'
\echo ' 5. The article-tagged bucket, by category'
\echo '================================================'
SELECT COALESCE(c.name, '(none)') AS category, count(*) AS n
FROM   core_article a
LEFT   JOIN core_category c ON c.id = a.category_id
WHERE  a.content_type = 'article'
GROUP  BY 1 ORDER BY n DESC LIMIT 15;

\echo ''
\echo '================================================'
\echo ' 6. Twenty newest article-tagged titles, to eyeball'
\echo '================================================'
SELECT left(title, 70) AS title, author,
       length(content) AS body, publish_date::date
FROM   core_article
WHERE  content_type = 'article'
ORDER  BY publish_date DESC
LIMIT  20;

\echo ''
\echo '================================================'
\echo ' 7. The 26 already tagged news, for comparison'
\echo '================================================'
SELECT left(title, 70) AS title, author,
       length(content) AS body, publish_date::date
FROM   core_article
WHERE  content_type = 'news'
ORDER  BY publish_date DESC
LIMIT  26;
