from django.db import migrations


def backfill_article_like_count(apps, schema_editor):
    """Backfill Article.like_count from ArticleLike relation counts."""
    Article = apps.get_model('core', 'Article')
    ArticleLike = apps.get_model('core', 'ArticleLike')

    for article in Article.objects.all():
        count = ArticleLike.objects.filter(article=article).count()
        if count > 0:
            Article.objects.filter(pk=article.pk).update(like_count=count)


def reverse_backfill(apps, schema_editor):
    """Reset all Article.like_count to 0."""
    Article = apps.get_model('core', 'Article')
    Article.objects.all().update(like_count=0)


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0060_article_like_count_usersession'),
    ]

    operations = [
        migrations.RunPython(backfill_article_like_count, reverse_backfill),
    ]
