"""Rejoin the migration graph.

main and this branch each added an identical create-cache-table migration
under a different number (0177 and 0181), leaving two leaf nodes. Both run
createcachetable, which is idempotent, so applying both is harmless — this
merge exists only to give the graph a single head again.
"""

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0177_create_cache_table'),
        ('core', '0185_alter_articlemedia_video_url'),
    ]

    operations = [
    ]
