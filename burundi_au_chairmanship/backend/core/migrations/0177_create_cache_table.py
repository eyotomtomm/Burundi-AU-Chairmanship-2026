"""Create the database cache table.

The cache table is needed whenever REDIS_URL is unset, because the cache then
falls back to DatabaseCache so DRF throttle counters are shared between
workers instead of being counted per-process. Doing it here rather than in the
deploy spec means a plain redeploy is enough — no spec change, no doctl.

createcachetable is idempotent and only touches caches that actually use the
database backend, so this is a no-op once Redis is configured.
"""

from django.core.management import call_command
from django.db import migrations


def create_cache_table(apps, schema_editor):
    call_command('createcachetable', verbosity=0)


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0176_official_posting_accounts'),
    ]

    operations = [
        migrations.RunPython(create_cache_table, migrations.RunPython.noop),
    ]
