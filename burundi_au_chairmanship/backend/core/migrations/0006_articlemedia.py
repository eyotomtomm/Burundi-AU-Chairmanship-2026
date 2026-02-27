from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0005_category_article_category_fk'),
    ]

    operations = [
        migrations.CreateModel(
            name='ArticleMedia',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('media_type', models.CharField(choices=[('image', 'Image'), ('video', 'Video')], default='image', max_length=10)),
                ('image', models.ImageField(blank=True, upload_to='article_media/')),
                ('video_url', models.URLField(blank=True)),
                ('caption', models.CharField(blank=True, max_length=300)),
                ('caption_fr', models.CharField(blank=True, max_length=300)),
                ('order', models.IntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('article', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='media', to='core.article')),
            ],
            options={
                'ordering': ['order'],
                'verbose_name_plural': 'Article Media',
            },
        ),
    ]
