from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0135_emergency_contact'),
    ]

    operations = [
        # Use RunSQL with IF NOT EXISTS because the column may already
        # exist in production (added before the migration was tracked).
        migrations.RunSQL(
            sql="ALTER TABLE core_appsettings ADD COLUMN IF NOT EXISTS facts_enabled boolean DEFAULT true NOT NULL;",
            reverse_sql="ALTER TABLE core_appsettings DROP COLUMN IF EXISTS facts_enabled;",
            state_operations=[
                migrations.AddField(
                    model_name='appsettings',
                    name='facts_enabled',
                    field=models.BooleanField(default=True, help_text='Show Facts & Quotes section in the app'),
                ),
            ],
        ),
        migrations.CreateModel(
            name='FactCategory',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100)),
                ('name_fr', models.CharField(blank=True, max_length=100)),
                ('icon_name', models.CharField(blank=True, help_text='Material icon name', max_length=50)),
                ('color', models.CharField(default='#1EB53A', max_length=10)),
                ('order', models.IntegerField(default=0)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'verbose_name': 'Fact Category',
                'verbose_name_plural': 'Fact Categories',
                'ordering': ['order', 'name'],
            },
        ),
        migrations.CreateModel(
            name='Fact',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=300)),
                ('title_fr', models.CharField(blank=True, max_length=300)),
                ('content', models.TextField()),
                ('content_fr', models.TextField(blank=True)),
                ('fact_type', models.CharField(choices=[('fact', 'Fact'), ('quote', 'Quote')], default='fact', max_length=10)),
                ('source', models.CharField(blank=True, max_length=300)),
                ('source_fr', models.CharField(blank=True, max_length=300)),
                ('author_name', models.CharField(blank=True, max_length=200)),
                ('author_title', models.CharField(blank=True, max_length=300)),
                ('author_title_fr', models.CharField(blank=True, max_length=300)),
                ('image', models.ImageField(blank=True, upload_to='facts/')),
                ('is_active', models.BooleanField(default=True)),
                ('is_featured', models.BooleanField(default=False, help_text='Show on home screen carousel')),
                ('status', models.CharField(choices=[('draft', 'Draft'), ('scheduled', 'Scheduled'), ('published', 'Published'), ('archived', 'Archived')], default='published', max_length=20)),
                ('order', models.IntegerField(default=0)),
                ('view_count', models.PositiveIntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('category', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='facts', to='core.factcategory')),
            ],
            options={
                'ordering': ['order', '-created_at'],
            },
        ),
    ]
