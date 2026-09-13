"""Give every article its other language.

Imported X posts arrive in one language. A French post was written into the
English fields as well, so switching the app to English handed the reader
the same French back; an English post left the French fields empty and the
app fell back to English. Either way the language toggle did nothing.

This fills the missing side, and puts a French post's English where the app
looks for it:

    python manage.py translate_articles --dry-run   # what would be done
    python manage.py translate_articles --limit 20  # a first batch
    python manage.py translate_articles             # the rest

Safe to stop and re-run: an article with both languages is passed over, so
a second run picks up wherever a rate limit ended the first.
"""
import time

from django.core.management.base import BaseCommand

from core.models import Article
from core.translation import guess_language, translate_text


class Command(BaseCommand):
    help = "Fill in each article's missing English or French text"

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true',
                            help='Report what would be translated, change nothing')
        parser.add_argument('--limit', type=int, default=0,
                            help='Stop after this many articles')
        parser.add_argument('--sleep', type=float, default=1.0,
                            help='Seconds between articles (default: 1.0)')

    def needs_translation(self, article):
        """An article missing a language, or holding one twice."""
        return not article.title_fr.strip() or article.title_fr == article.title

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        limit = options['limit']
        pause = options['sleep']

        pending = [a for a in Article.objects.all().order_by('-publish_date')
                   if self.needs_translation(a)]
        self.stdout.write(f'{len(pending)} of {Article.objects.count()} '
                          f'articles have only one language')
        if limit:
            pending = pending[:limit]
        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN — nothing is saved\n'))

        done = failed = skipped = 0
        for article in pending:
            lang = guess_language(article.title + ' ' + article.content)
            if lang not in ('en', 'fr'):
                # Amharic posts land here. A wrong guess writes gibberish
                # into an article, so they are left as they are.
                skipped += 1
                self.stdout.write(f'  [skip {lang or "?"}] {article.title[:60]}')
                continue

            if dry_run:
                other = 'en' if lang == 'fr' else 'fr'
                self.stdout.write(f'  [{lang}->{other}] {article.title[:60]}')
                done += 1
                continue

            try:
                if lang == 'fr':
                    # The French text is sitting in the English fields. Move
                    # it across and put the translation where English belongs.
                    french_title, french_body = article.title, article.content
                    title = translate_text(french_title, 'fr', 'en')
                    body = translate_text(french_body, 'fr', 'en') if french_body else ''
                    if not title:
                        raise RuntimeError('no translation returned')
                    article.title, article.content = title[:300], body
                    article.title_fr, article.content_fr = french_title[:300], french_body
                else:
                    title = translate_text(article.title, 'en', 'fr')
                    body = translate_text(article.content, 'en', 'fr') if article.content else ''
                    if not title:
                        raise RuntimeError('no translation returned')
                    article.title_fr, article.content_fr = title[:300], body
                article.save(update_fields=['title', 'content',
                                            'title_fr', 'content_fr'])
                done += 1
                self.stdout.write(f'  [{lang}] {article.title[:60]}')
            except Exception as e:
                failed += 1
                self.stdout.write(self.style.ERROR(
                    f'  FAILED {article.id}: {e}'))
            time.sleep(pause)

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(
            f'Done! Translated: {done}, Skipped: {skipped}, Failed: {failed}'))
        if failed:
            self.stdout.write(
                'Failures are usually a rate limit. Re-run to pick them up.')
