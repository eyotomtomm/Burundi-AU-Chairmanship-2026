"""Undo the stored HTML escaping, and fill DiscussionTag from existing posts.

Comment text used to be escaped on the way *in*, which is the wrong end: the
Flutter app renders plain text and Django's templates escape on output, so
"Burundi's" reached readers as "Burundi&#x27;s". The write-side escaping is
gone; this unescapes what it already stored.
"""
import html
import re

from django.db import migrations

# Every model whose user-authored text went through escape() on save.
ESCAPED_TEXT_FIELDS = [
    ('ArticleComment', 'content'),
    ('MagazineComment', 'content'),
    ('VideoComment', 'content'),
    ('GalleryComment', 'content'),
    ('LiveFeedComment', 'content'),
    ('EventComment', 'content'),
    ('DiscussionReply', 'content'),
    ('DirectMessage', 'content'),
]

TAG_PATTERN = re.compile(r'#([\wÀ-ɏ]+)')
# Only rows that actually carry an entity need rewriting.
ENTITY = re.compile(r'&(?:amp|lt|gt|quot|#x27|#39);')


def unescape_stored_text(apps, schema_editor):
    for model_name, field in ESCAPED_TEXT_FIELDS:
        try:
            Model = apps.get_model('core', model_name)
        except LookupError:
            continue
        batch = []
        for obj in Model.objects.filter(**{f'{field}__contains': '&'}).iterator(chunk_size=500):
            value = getattr(obj, field) or ''
            if not ENTITY.search(value):
                continue
            setattr(obj, field, html.unescape(value))
            batch.append(obj)
            if len(batch) >= 500:
                Model.objects.bulk_update(batch, [field])
                batch = []
        if batch:
            Model.objects.bulk_update(batch, [field])


def backfill_tags(apps, schema_editor):
    Discussion = apps.get_model('core', 'Discussion')
    DiscussionTag = apps.get_model('core', 'DiscussionTag')
    rows = []
    for pk, content in Discussion.objects.values_list('id', 'content').iterator(chunk_size=500):
        for tag in {t.lower()[:64] for t in TAG_PATTERN.findall(content or '')}:
            rows.append(DiscussionTag(discussion_id=pk, tag=tag))
        if len(rows) >= 1000:
            DiscussionTag.objects.bulk_create(rows, ignore_conflicts=True)
            rows = []
    if rows:
        DiscussionTag.objects.bulk_create(rows, ignore_conflicts=True)


def drop_tags(apps, schema_editor):
    apps.get_model('core', 'DiscussionTag').objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0179_explore_block_tags_moderation'),
    ]

    operations = [
        # Unescaping is not reversible — re-escaping would mangle text that
        # legitimately contains an ampersand.
        migrations.RunPython(unescape_stored_text, migrations.RunPython.noop),
        migrations.RunPython(backfill_tags, drop_tags),
    ]
