#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Scrape all posts from @BurundinAddis using gallery-dl
#
# PREREQUISITES:
#   1. pip3 install gallery-dl
#   2. Be logged into X (twitter.com) in Firefox or Chrome
#
# USAGE:
#   ./scrape_x.sh              # uses Firefox cookies (default)
#   ./scrape_x.sh chrome       # uses Chrome cookies
#   ./scrape_x.sh firefox      # uses Firefox cookies explicitly
#
# OUTPUT:
#   media/x_scrape/BurundinAddis/   — images & videos
#   media/x_scrape/BurundinAddis/*.json — tweet metadata
#   media/x_scrape/.logs/*.log      — per-phase gallery-dl output
#
# AFTER SCRAPING:
#   python manage.py import_x_posts   — imports into Django DB
#
# ⚠ SECURITY: This script reads your personal browser cookies to
#   authenticate with X.  NEVER run it in CI, Docker, or on a shared
#   machine — the cookies grant full access to your X account.
#   Run only on your local workstation.
# ─────────────────────────────────────────────────────────────

set -e

# Refuse to run in CI or containerised environments
if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ] || [ -f /.dockerenv ]; then
  echo "ERROR: This script reads your personal browser cookies."
  echo "       Never run it in CI, Docker, or shared environments."
  exit 1
fi
cd "$(dirname "$0")"

BROWSER="${1:-firefox}"
OUTPUT_DIR="media/x_scrape"
LOG_DIR="$OUTPUT_DIR/.logs"
ACCOUNT="https://x.com/BurundinAddis"
# The timeline stops at roughly 3200 posts; search reaches past that.
SEARCH="https://x.com/search?q=from%3ABurundinAddis+since%3A2025-01-01&src=typed_query&f=live"

echo "=== Scraping @BurundinAddis from X ==="
echo "Browser cookies: $BROWSER"
echo "Output dir: $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# X throttles a long cursor walk by answering 404, which gallery-dl reports as
# a failed run even though everything up to that point downloaded fine. It
# prints the cursor it stopped at, so the walk can be picked back up rather
# than restarted; the download archive keeps a resume from refetching anything.
scrape_phase() {
  name="$1"
  url="$2"
  log="$LOG_DIR/$name.log"
  cursor=""
  status=0
  attempt=1

  while [ "$attempt" -le 5 ]; do
    : > "$log"
    if [ -n "$cursor" ]; then
      gallery-dl \
        --cookies-from-browser "$BROWSER" \
        --download-archive "$OUTPUT_DIR/.archive.sqlite3" \
        --sleep-request 1-3 \
        -o "cursor=$cursor" \
        -D "$OUTPUT_DIR" \
        "$url" 2>&1 | tee -a "$log"
    else
      gallery-dl \
        --cookies-from-browser "$BROWSER" \
        --download-archive "$OUTPUT_DIR/.archive.sqlite3" \
        --sleep-request 1-3 \
        -D "$OUTPUT_DIR" \
        "$url" 2>&1 | tee -a "$log"
    fi
    status=${PIPESTATUS[0]}

    if [ "$status" -eq 0 ]; then
      return 0
    fi

    # "Use '-o cursor=3_2018349889395024155/' to continue downloading"
    cursor=$(sed -n "s/.*-o cursor=\([^']*\)'.*/\1/p" "$log" | tail -1)
    if [ -z "$cursor" ]; then
      echo ""
      echo "!! $name phase stopped (exit $status) and gave no resume cursor."
      return "$status"
    fi

    echo ""
    echo "!! $name phase interrupted (exit $status) — resuming from $cursor"
    echo "   in 30s (attempt $attempt of 5)"
    sleep 30
    attempt=$((attempt + 1))
  done

  echo ""
  echo "!! $name phase still failing after 5 attempts."
  return "$status"
}

# A failure in one phase must not skip the other: the search phase is the only
# one that reaches posts older than the timeline limit, and it used to be
# abandoned whenever the timeline hit a 404 on its way down.
set +e
echo "=== Phase 1/2: timeline ==="
scrape_phase timeline "$ACCOUNT"
TIMELINE_STATUS=$?

echo ""
echo "=== Phase 2/2: search (Jan 2025 - now) ==="
scrape_phase search "$SEARCH"
SEARCH_STATUS=$?
set -e

echo ""
echo "=== Done ==="
[ "$TIMELINE_STATUS" -eq 0 ] && echo "Timeline: complete" || echo "Timeline: INCOMPLETE (exit $TIMELINE_STATUS, see $LOG_DIR/timeline.log)"
[ "$SEARCH_STATUS" -eq 0 ] && echo "Search:   complete" || echo "Search:   INCOMPLETE (exit $SEARCH_STATUS, see $LOG_DIR/search.log)"

TOTAL_JSON=$(find "$OUTPUT_DIR" -name "*.json" | wc -l | tr -d ' ')
TOTAL_MEDIA=$(find "$OUTPUT_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.mp4" \) | wc -l | tr -d ' ')
echo "Posts scraped: $TOTAL_JSON"
echo "Media files: $TOTAL_MEDIA"
echo ""
echo "Next step: python manage.py import_x_posts"

# Only a run where both phases failed is a failed run; a partial pass still
# leaves new posts on disk for the importer.
if [ "$TIMELINE_STATUS" -ne 0 ] && [ "$SEARCH_STATUS" -ne 0 ]; then
  exit 1
fi
