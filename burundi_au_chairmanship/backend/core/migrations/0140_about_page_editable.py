from django.db import migrations, models


def seed_about_features(apps, schema_editor):
    AboutFeature = apps.get_model('core', 'AboutFeature')
    if not AboutFeature.objects.exists():
        features = [
            ('News', '', 'article', '#1EB53A', 0),
            ('Events Calendar', '', 'event', '#CE1126', 1),
            ('Magazine', '', 'auto_stories', '#D4A017', 2),
            ('Translation', '', 'translate', '#1EB53A', 3),
            ('Weather', '', 'wb_sunny', '#D4A017', 4),
            ('Diplomacy', '', 'account_balance', '#CE1126', 5),
        ]
        for title, title_fr, icon_name, color, order in features:
            AboutFeature.objects.create(
                title=title,
                title_fr=title_fr,
                icon_name=icon_name,
                color=color,
                order=order,
                is_active=True,
            )


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0139_add_live_feeds_enabled'),
    ]

    operations = [
        # New AppSettings fields
        migrations.AddField(
            model_name='appsettings',
            name='about_mission_title',
            field=models.CharField(blank=True, default='Our Mission', help_text='About page mission section title (English)', max_length=100),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='about_mission_title_fr',
            field=models.CharField(blank=True, default='Notre Mission', help_text='About page mission section title (French)', max_length=100),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='about_features_title',
            field=models.CharField(blank=True, default='Key Features', help_text='About page features section title (English)', max_length=100),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='about_features_title_fr',
            field=models.CharField(blank=True, default='Fonctionnalit\u00e9s', help_text='About page features section title (French)', max_length=100),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='contact_website',
            field=models.CharField(blank=True, default='burundi4africa.com', help_text='Contact website display name', max_length=200),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='contact_website_url',
            field=models.URLField(blank=True, default='https://burundi4africa.com', help_text='Contact website URL'),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='contact_email',
            field=models.EmailField(blank=True, default='info@burundi4africa.com', help_text='Contact email address', max_length=254),
        ),
        # AboutFeature model
        migrations.CreateModel(
            name='AboutFeature',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=100)),
                ('title_fr', models.CharField(blank=True, max_length=100)),
                ('icon_name', models.CharField(choices=[
                    ('article', 'News'), ('event', 'Events'), ('auto_stories', 'Magazine'),
                    ('translate', 'Translation'), ('wb_sunny', 'Weather'),
                    ('account_balance', 'Diplomacy'), ('public', 'Globe'),
                    ('group', 'Community'), ('school', 'Education'), ('gavel', 'Governance'),
                ], max_length=50)),
                ('color', models.CharField(choices=[
                    ('#1EB53A', 'Green'), ('#CE1126', 'Red'), ('#D4A017', 'Gold'),
                ], default='#1EB53A', max_length=10)),
                ('order', models.IntegerField(default=0)),
                ('is_active', models.BooleanField(default=True)),
            ],
            options={
                'verbose_name': 'About Feature',
                'verbose_name_plural': 'About Features',
                'ordering': ['order'],
            },
        ),
        # Seed default features
        migrations.RunPython(seed_about_features, migrations.RunPython.noop),
    ]
