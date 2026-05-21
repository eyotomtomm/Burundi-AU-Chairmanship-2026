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
#
# AFTER SCRAPING:
#   python manage.py import_x_posts   — imports into Django DB
# ─────────────────────────────────────────────────────────────

set -e
cd "$(dirname "$0")"

BROWSER="${1:-firefox}"
OUTPUT_DIR="media/x_scrape"
ACCOUNT="https://x.com/BurundinAddis"

echo "=== Scraping @BurundinAddis from X ==="
echo "Browser cookies: $BROWSER"
echo "Output dir: $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"

# gallery-dl with:
#   --cookies-from-browser: grab session from your browser
#   --download-archive: track what's already downloaded (resume support)
#   -D: base download directory
gallery-dl \
  --cookies-from-browser "$BROWSER" \
  --download-archive "$OUTPUT_DIR/.archive.sqlite3" \
  -D "$OUTPUT_DIR" \
  "$ACCOUNT"

# Also scrape via search to get posts beyond the ~3200 timeline limit
echo ""
echo "=== Scraping older posts via search (Jan 2025 - now) ==="
gallery-dl \
  --cookies-from-browser "$BROWSER" \
  --download-archive "$OUTPUT_DIR/.archive.sqlite3" \
  -D "$OUTPUT_DIR" \
  "https://x.com/search?q=from%3ABurundinAddis+since%3A2025-01-01&src=typed_query&f=live"

echo ""
echo "=== Done! ==="
TOTAL_JSON=$(find "$OUTPUT_DIR" -name "*.json" | wc -l | tr -d ' ')
TOTAL_MEDIA=$(find "$OUTPUT_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.mp4" \) | wc -l | tr -d ' ')
echo "Posts scraped: $TOTAL_JSON"
echo "Media files: $TOTAL_MEDIA"
echo ""
echo "Next step: python manage.py import_x_posts"
