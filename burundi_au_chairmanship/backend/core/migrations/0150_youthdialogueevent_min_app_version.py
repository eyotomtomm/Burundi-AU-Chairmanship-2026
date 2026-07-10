from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0149_add_registration_dates'),
    ]

    operations = [
        migrations.AddField(
            model_name='youthdialogueevent',
            name='min_app_version',
            field=models.CharField(blank=True, default='', help_text='Minimum app version required to register (e.g. 1.2.16). Leave blank to allow all versions.', max_length=20),
        ),
    ]
