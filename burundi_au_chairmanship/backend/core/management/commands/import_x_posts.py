"""
Import scraped @BurundinAddis X posts into Articles, Events, and LiveFeeds.

Reads JSON metadata files produced by gallery-dl from media/x_scrape/.

Usage:
    # Step 1: Scrape (run once, or re-run to get new posts)
    ./scrape_x.sh

    # Step 2: Import into Django
    python manage.py import_x_posts                    # import all
    python manage.py import_x_posts --dry-run          # preview only
    python manage.py import_x_posts --since 2026-01-01 # filter by date
"""

import json
import os
import re
from datetime import datetime
from pathlib import Path

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import Article, ArticleMedia, Event, LiveFeed, Category


# Keywords used to auto-categorize posts
EVENT_KEYWORDS = [
    'summit', 'conference', 'meeting', 'forum', 'ceremony', 'inauguration',
    'commemoration', 'celebration', 'visited', 'visit', 'took part',
    'participated', 'held at', 'held in', 'hosted', 'hosting',
    'sommet', 'conférence', 'réunion', 'forum', 'cérémonie',
    'visite', 'a participé', 'tenu à', 'accueille',
]
LIVEFEED_KEYWORDS = [
    'chairmanship', 'a-rise', 'arise', 'agenda 2063', 'agenda2063',
    'au chair', 'burundi4africa', 'présidence',
]
CATEGORY_KEYWORDS = {
    'Diplomacy': [
        'ambassador', 'diplomatic', 'bilateral', 'consul', 'embassy',
        'foreign affairs', 'cooperation', 'ambassadeur', 'diplomati',
    ],
    'Governance': [
        'election', 'parliament', 'minister', 'cabinet', 'appointed',
        'prime minister', 'president', 'gouvern', 'élu', 'nommé',
        'premier ministre', 'voted', 'vote',
    ],
    'Health': [
        'health', 'santé', 'medical', 'hospital', 'doctor',
    ],
    'Economy': [
        'investment', 'trade', 'economic', 'factory', 'production',
        'business', 'commerce', 'investissement',
    ],
    'Be 4 Africa': [
        'chairmanship', 'a-rise', 'burundi4africa', 'présidence de l\'ua',
        'au chair',
    ],
    'Culture': [
        'celebration', 'holiday', 'independence day', 'beautiful',
        'tourism', 'culture', 'fête',
    ],
}
CATEGORY_FR_MAP = {
    'Diplomacy': 'Diplomatie',
    'Governance': 'Gouvernance',
    'Health': 'Santé',
    'Economy': 'Économie',
    'Be 4 Africa': "Présidence de l'UA",
    'Culture': 'Culture',
}
CATEGORY_COLORS = {
    'Diplomacy': '#1EB53A',
    'Governance': '#CE1126',
    'Health': '#0077B6',
    'Economy': '#F4A261',
    'Be 4 Africa': '#FFD700',
    'Culture': '#9B59B6',
}

AUTHOR = 'Burundi'


def classify_category(text):
    """Auto-detect category from tweet text."""
    text_lower = text.lower()
    scores = {}
    for cat, keywords in CATEGORY_KEYWORDS.items():
        scores[cat] = sum(1 for kw in keywords if kw in text_lower)
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else 'Diplomacy'


def is_event_post(text):
    """Check if the post describes an event."""
    text_lower = text.lower()
    return any(kw in text_lower for kw in EVENT_KEYWORDS)


def is_livefeed_post(text):
    """Check if the post is related to Be 4 Africa / live feed."""
    text_lower = text.lower()
    return any(kw in text_lower for kw in LIVEFEED_KEYWORDS)


# A run of two or more handles or tags in a row is a credit dump, not part of
# the sentence — the old code deleted every tag instead, which turned
# "#Burundi joins the AU family" into a headline starting mid-air.
MENTION_RUN = re.compile(r'(?:@\w+\s*){2,}')
HASHTAG_RUN = re.compile(r'(?:#\w+\s*){2,}')
# Periods that close an abbreviation rather than a sentence: "H.E.", "Amb.".
ABBREV_END = re.compile(r'(?:\b[A-Z]|\b(?:H\.E|Hon|Amb|Dr|Mr|Mrs|Ms|Prof|St|No|Jr|Sr|etc|vs))\.$')

# Display names arrive carrying their own honorific ("Amb. Willy Nyamitwe"),
# which doubles up when the sentence already opened with one.
NICK_HONORIFIC = re.compile(r'^(?:H\.E|Amb|Hon|Dr|Prof|Mr|Mrs|Ms)\.?\s+', re.I)

IMAGE_EXTS = ('.jpg', '.jpeg', '.png', '.webp')
VIDEO_EXTS = ('.mp4', '.webm')


def clean_prose(text, mentions=()):
    """Tweet text as prose: no t.co links, tags as words, handles as names."""
    nicks = {
        m['name'].lower(): NICK_HONORIFIC.sub('', (m.get('nick') or m['name']).strip())
        for m in mentions or () if m.get('name')
    }
    clean = re.sub(r'https?://\S+', ' ', text)
    clean = HASHTAG_RUN.sub(' ', MENTION_RUN.sub(' ', clean))
    # A lone handle names a person; X shows the display name, so we do too.
    clean = re.sub(r'@(\w+)', lambda m: nicks.get(m.group(1).lower(), m.group(1)), clean)
    clean = re.sub(r'#(\w+)', r'\1', clean)
    clean = re.sub(r'\s+', ' ', clean)
    # Removing markup leaves its space behind: "Nyamitwe , Permanent".
    clean = re.sub(r'\s+([,.;:!?\u00bb)\]])', r'\1', clean)
    return clean.strip(' ,;:-\u2013\u2014')


def first_sentence(text, min_len=25):
    """The first real sentence, ignoring the periods inside abbreviations."""
    for m in re.finditer(r'[.!?](?=\s|$)', text):
        head = text[:m.end()]
        if len(head) >= min_len and not ABBREV_END.search(head):
            return head
    return text


def make_title(text, max_len=200, mentions=()):
    """A headline a reader would say out loud, cut on a word boundary."""
    clean = first_sentence(clean_prose(text, mentions))
    if len(clean) > max_len:
        clean = clean[:max_len].rsplit(' ', 1)[0].rstrip(' ,;:') + '\u2026'
    return clean or text[:max_len]


class Command(BaseCommand):
    help = 'Import gallery-dl scraped @BurundinAddis X posts into Articles, Events, and LiveFeeds'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Preview what would be imported without saving',
        )
        parser.add_argument(
            '--since',
            type=str,
            default='2025-01-01',
            help='Only import posts from this date onwards (YYYY-MM-DD, default: 2025-01-01)',
        )
        parser.add_argument(
            '--scrape-dir',
            type=str,
            default='',
            help='Path to gallery-dl output directory (default: media/x_scrape)',
        )

    def attach_media(self, article, images, videos, caption, is_french):
        """Fill the article's gallery from the post's remaining media."""
        caption_fr = caption if is_french else ''
        for order, image in enumerate(images):
            media = ArticleMedia(
                article=article, media_type='image',
                caption=caption, caption_fr=caption_fr, order=order,
            )
            with open(image, 'rb') as img_f:
                media.image.save(image.name, ContentFile(img_f.read()), save=False)
            media.save()
        for order, video in enumerate(videos, start=len(images)):
            # ArticleMedia holds videos by URL and the app plays that URL
            # in-app, so the file has to reach the same storage the images do
            # before there is anything to point at.
            with open(video, 'rb') as vid_f:
                stored = default_storage.save(
                    f'article_media/{video.name}', ContentFile(vid_f.read()))
            ArticleMedia.objects.create(
                article=article, media_type='video',
                video_url=default_storage.url(stored),
                caption=caption, caption_fr=caption_fr, order=order,
            )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        since_str = options['since']
        since_date = datetime.strptime(since_str, '%Y-%m-%d')

        scrape_dir = options['scrape_dir']
        if not scrape_dir:
            scrape_dir = os.path.join(settings.BASE_DIR, 'media', 'x_scrape')

        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN — nothing will be saved\n'))

        self.stdout.write(f'Scanning: {scrape_dir}')
        self.stdout.write(f'Since: {since_str}\n')

        # Find all JSON metadata files
        json_files = sorted(Path(scrape_dir).rglob('*.json'))
        if not json_files:
            self.stdout.write(self.style.ERROR(
                f'No JSON files found in {scrape_dir}\n'
                'Run ./scrape_x.sh first to scrape posts from X.'
            ))
            return

        self.stdout.write(f'Found {len(json_files)} scraped posts\n')

        articles_created = 0
        events_created = 0
        livefeeds_created = 0
        skipped = 0
        errors = 0

        for json_file in json_files:
            try:
                with open(json_file) as f:
                    data = json.load(f)

                tweet_id = data.get('tweet_id') or data.get('id')
                if not tweet_id:
                    continue

                # Parse date
                date_str = data.get('date')
                if not date_str:
                    continue
                if isinstance(date_str, str):
                    # gallery-dl format: "2025-01-28 18:31:48"
                    try:
                        post_date = datetime.strptime(date_str, '%Y-%m-%d %H:%M:%S')
                    except ValueError:
                        post_date = datetime.strptime(date_str[:10], '%Y-%m-%d')
                elif isinstance(date_str, (int, float)):
                    post_date = datetime.fromtimestamp(date_str)
                else:
                    continue

                # Filter by date
                if post_date < since_date:
                    continue

                post_date_aware = timezone.make_aware(post_date)
                text = data.get('content') or data.get('text') or ''
                if not text:
                    continue

                # Check if already imported. Keyed on the tweet text, not on
                # the title: the title is derived, so improving how it reads
                # must not re-import every post that already landed.
                title = make_title(text, mentions=data.get('mentions'))
                is_french = data.get('lang') == 'fr'
                if Article.objects.filter(content=text).exists():
                    skipped += 1
                    continue

                # Classify
                cat_name = classify_category(text)
                should_be_event = is_event_post(text)
                should_be_livefeed = is_livefeed_post(text)

                # Find the post's media. gallery-dl names them "<id>_1.jpg"
                # and leaves ".part" files behind mid-download, hence the
                # extension whitelist rather than a bare glob.
                parent_dir = json_file.parent
                media_files = sorted({
                    path
                    for stem in (json_file.stem, str(tweet_id))
                    for path in parent_dir.glob(f'{stem}_*')
                    if path.suffix.lower() in IMAGE_EXTS + VIDEO_EXTS
                })
                image_files = [p for p in media_files if p.suffix.lower() in IMAGE_EXTS]
                video_files = [p for p in media_files if p.suffix.lower() in VIDEO_EXTS]

                if not dry_run:
                    # Get or create category
                    category, _ = Category.objects.get_or_create(
                        name=cat_name,
                        defaults={
                            'name_fr': CATEGORY_FR_MAP.get(cat_name, cat_name),
                            'color': CATEGORY_COLORS.get(cat_name, '#1EB53A'),
                        },
                    )

                    # Create Article. A French post fills the French fields
                    # too, so the app shows it as written instead of falling
                    # back to an English version that does not exist.
                    article = Article(
                        title=title,
                        title_fr=title if is_french else '',
                        content=text,
                        content_fr=text if is_french else '',
                        author=AUTHOR,
                        category=category,
                        publish_date=post_date_aware,
                        status='published',
                    )
                    # Attach first image if available
                    if image_files:
                        with open(image_files[0], 'rb') as img_f:
                            article.image.save(
                                image_files[0].name,
                                ContentFile(img_f.read()),
                                save=False,
                            )
                    article.save()

                    # The lead image sits at the top of the article; the rest
                    # of the post's media becomes the gallery, each piece
                    # captioned so it is not a bare photo.
                    self.attach_media(
                        article, image_files[1:], video_files,
                        title[:300], is_french,
                    )

                    # Create Event if applicable
                    if should_be_event:
                        Event.objects.get_or_create(
                            name=title,
                            defaults={
                                'description': text,
                                'address': 'See article for details',
                                'latitude': 9.0380,   # AU HQ default
                                'longitude': 38.7506,
                                'event_date': post_date_aware,
                                'status': 'published',
                            },
                        )
                        events_created += 1

                    # Create LiveFeed if applicable
                    if should_be_livefeed:
                        LiveFeed.objects.get_or_create(
                            title=title,
                            defaults={
                                'description': text,
                                'stream_url': f'https://x.com/BurundinAddis/status/{tweet_id}',
                                'stream_type': 'external',
                                'status': 'recorded',
                                'content_status': 'published',
                                'scheduled_time': post_date_aware,
                            },
                        )
                        livefeeds_created += 1

                articles_created += 1
                img_count = len(image_files)
                if video_files:
                    flags_extra = f', {len(video_files)} video'
                else:
                    flags_extra = ''
                flags = []
                if should_be_event:
                    flags.append('EVENT')
                if should_be_livefeed:
                    flags.append('LIVEFEED')
                flag_str = f' [{", ".join(flags)}]' if flags else ''
                self.stdout.write(
                    f'  [{cat_name}]{flag_str} {title[:70]} '
                    f'({img_count} img{"s" if img_count != 1 else ""}{flags_extra})'
                )

            except Exception as e:
                errors += 1
                self.stdout.write(self.style.ERROR(f'  ERROR {json_file.name}: {e}'))

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(
            f'Done! Articles: {articles_created}, Events: {events_created}, '
            f'LiveFeeds: {livefeeds_created}, Skipped: {skipped}, Errors: {errors}'
        ))
        self.stdout.write(f'Total JSON files processed: {len(json_files)}')
        if events_created:
            self.stdout.write(self.style.WARNING(
                '\nNOTE: Events were created with default AU HQ coordinates.\n'
                'Update the address and lat/lng in the admin panel for accuracy.'
            ))
