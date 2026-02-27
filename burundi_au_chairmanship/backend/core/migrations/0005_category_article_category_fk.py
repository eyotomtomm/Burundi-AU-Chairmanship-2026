"""
Create Category model, seed the 4 existing categories, and migrate
Article.category from CharField → ForeignKey(Category).
"""
from django.db import migrations, models
import django.db.models.deletion


def seed_categories_and_migrate(apps, schema_editor):
    Category = apps.get_model('core', 'Category')
    Article = apps.get_model('core', 'Article')

    seed = [
        {'name': 'Politics', 'name_fr': 'Politique', 'color': '#CE1126', 'order': 0},
        {'name': 'Economy', 'name_fr': 'Économie', 'color': '#17a2b8', 'order': 1},
        {'name': 'Culture', 'name_fr': 'Culture', 'color': '#D4AF37', 'order': 2},
        {'name': 'Diplomacy', 'name_fr': 'Diplomatie', 'color': '#1EB53A', 'order': 3},
    ]
    cat_map = {}
    for item in seed:
        cat, _ = Category.objects.get_or_create(name=item['name'], defaults=item)
        cat_map[item['name'].lower()] = cat

    # Migrate existing articles
    for article in Article.objects.all():
        old_val = (article.category_old or '').strip().lower()
        if old_val in cat_map:
            article.category_new = cat_map[old_val]
            article.save(update_fields=['category_new'])


def reverse_migration(apps, schema_editor):
    Article = apps.get_model('core', 'Article')
    for article in Article.objects.select_related('category_new').all():
        if article.category_new:
            article.category_old = article.category_new.name.lower()
            article.save(update_fields=['category_old'])


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0004_article_view_count_articlecomment_articlelike'),
    ]

    operations = [
        # 1. Create Category table
        migrations.CreateModel(
            name='Category',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=50, unique=True)),
                ('name_fr', models.CharField(blank=True, max_length=50)),
                ('color', models.CharField(default='#1EB53A', help_text='Hex color e.g. #CE1126', max_length=10)),
                ('order', models.IntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'ordering': ['order'],
                'verbose_name_plural': 'Categories',
            },
        ),

        # 2. Rename old category column
        migrations.RenameField(
            model_name='article',
            old_name='category',
            new_name='category_old',
        ),

        # 3. Add new FK column (nullable initially)
        migrations.AddField(
            model_name='article',
            name='category_new',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='articles',
                to='core.category',
            ),
        ),

        # 4. Seed categories + migrate data
        migrations.RunPython(seed_categories_and_migrate, reverse_migration),

        # 5. Remove old CharField
        migrations.RemoveField(
            model_name='article',
            name='category_old',
        ),

        # 6. Rename new FK to 'category'
        migrations.RenameField(
            model_name='article',
            old_name='category_new',
            new_name='category',
        ),
    ]
