from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0150_youthdialogueevent_min_app_version'),
    ]

    operations = [
        migrations.AddField(
            model_name='youthdialogueevent',
            name='id_card_visible_fields',
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='scan_result_visible_fields',
            field=models.JSONField(blank=True, default=list),
        ),
    ]
