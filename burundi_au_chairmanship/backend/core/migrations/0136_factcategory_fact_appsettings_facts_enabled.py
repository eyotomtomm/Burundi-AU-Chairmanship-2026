from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    """Idempotent migration: all database operations use IF NOT EXISTS
    so the migration succeeds even when the schema already exists in
    production (applied outside the migration tracker)."""

    dependencies = [
        ('core', '0135_emergency_contact'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[
                # Column -------------------------------------------------
                migrations.RunSQL(
                    sql=(
                        "ALTER TABLE core_appsettings "
                        "ADD COLUMN IF NOT EXISTS facts_enabled boolean NOT NULL DEFAULT true;"
                    ),
                    reverse_sql=(
                        "ALTER TABLE core_appsettings "
                        "DROP COLUMN IF EXISTS facts_enabled;"
                    ),
                ),
                # FactCategory table --------------------------------------
                migrations.RunSQL(
                    sql="""
                        CREATE TABLE IF NOT EXISTS "core_factcategory" (
                            "id" bigserial NOT NULL PRIMARY KEY,
                            "name" varchar(100) NOT NULL,
                            "name_fr" varchar(100) NOT NULL DEFAULT '',
                            "icon_name" varchar(50) NOT NULL DEFAULT '',
                            "color" varchar(10) NOT NULL DEFAULT '#1EB53A',
                            "order" integer NOT NULL DEFAULT 0,
                            "is_active" boolean NOT NULL DEFAULT true,
                            "created_at" timestamp with time zone NOT NULL DEFAULT now()
                        );
                    """,
                    reverse_sql='DROP TABLE IF EXISTS "core_fact"; DROP TABLE IF EXISTS "core_factcategory";',
                ),
                # Fact table ----------------------------------------------
                migrations.RunSQL(
                    sql="""
                        CREATE TABLE IF NOT EXISTS "core_fact" (
                            "id" bigserial NOT NULL PRIMARY KEY,
                            "title" varchar(300) NOT NULL,
                            "title_fr" varchar(300) NOT NULL DEFAULT '',
                            "content" text NOT NULL DEFAULT '',
                            "content_fr" text NOT NULL DEFAULT '',
                            "fact_type" varchar(10) NOT NULL DEFAULT 'fact',
                            "source" varchar(300) NOT NULL DEFAULT '',
                            "source_fr" varchar(300) NOT NULL DEFAULT '',
                            "author_name" varchar(200) NOT NULL DEFAULT '',
                            "author_title" varchar(300) NOT NULL DEFAULT '',
                            "author_title_fr" varchar(300) NOT NULL DEFAULT '',
                            "image" varchar(100) NOT NULL DEFAULT '',
                            "is_active" boolean NOT NULL DEFAULT true,
                            "is_featured" boolean NOT NULL DEFAULT false,
                            "status" varchar(20) NOT NULL DEFAULT 'published',
                            "order" integer NOT NULL DEFAULT 0,
                            "view_count" integer NOT NULL DEFAULT 0 CHECK ("view_count" >= 0),
                            "created_at" timestamp with time zone NOT NULL DEFAULT now(),
                            "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
                            "category_id" bigint NOT NULL REFERENCES "core_factcategory" ("id") DEFERRABLE INITIALLY DEFERRED
                        );
                        CREATE INDEX IF NOT EXISTS "core_fact_category_id_idx"
                            ON "core_fact" ("category_id");
                    """,
                    reverse_sql='DROP TABLE IF EXISTS "core_fact";',
                ),
            ],
            state_operations=[
                # These only update Django's internal model state — they
                # do NOT touch the database.
                migrations.AddField(
                    model_name='appsettings',
                    name='facts_enabled',
                    field=models.BooleanField(default=True, help_text='Show Facts & Quotes section in the app'),
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
            ],
        ),
    ]
