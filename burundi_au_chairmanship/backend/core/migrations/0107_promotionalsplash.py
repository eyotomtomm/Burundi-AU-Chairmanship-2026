from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0106_youth_dialogue_visibility_form_fields'),
    ]

    operations = [
        migrations.CreateModel(
            name='PromotionalSplash',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=200)),
                ('title_fr', models.CharField(blank=True, max_length=200)),
                ('image', models.ImageField(upload_to='promotional_splashes/')),
                ('action_url', models.CharField(blank=True, help_text='In-app route (e.g. /news) or external URL', max_length=500)),
                ('action_text', models.CharField(blank=True, help_text='Button text (e.g. Learn More)', max_length=100)),
                ('action_text_fr', models.CharField(blank=True, max_length=100)),
                ('auto_close_seconds', models.PositiveIntegerField(default=5, help_text='Seconds before auto-dismiss')),
                ('starts_at', models.DateTimeField()),
                ('ends_at', models.DateTimeField()),
                ('is_active', models.BooleanField(default=True)),
                ('show_once', models.BooleanField(default=False, help_text='If true, shown only once per user')),
                ('click_count', models.PositiveIntegerField(default=0)),
                ('view_count', models.PositiveIntegerField(default=0)),
                ('priority', models.IntegerField(default=0, help_text='Higher = shown first')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'verbose_name': 'Promotional Splash',
                'verbose_name_plural': 'Promotional Splashes',
                'ordering': ['-priority', '-created_at'],
                'indexes': [
                    models.Index(fields=['is_active', 'starts_at', 'ends_at'], name='core_promot_is_acti_idx'),
                ],
            },
        ),
    ]
