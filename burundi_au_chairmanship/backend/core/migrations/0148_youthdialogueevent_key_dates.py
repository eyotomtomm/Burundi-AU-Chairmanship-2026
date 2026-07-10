from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0147_youthdialoguesideevent'),
    ]

    operations = [
        migrations.AddField(
            model_name='youthdialogueevent',
            name='registration_start_date',
            field=models.DateField(blank=True, help_text='When registration opens', null=True),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='registration_end_date',
            field=models.DateField(blank=True, help_text='Registration deadline', null=True),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='event_start_date',
            field=models.DateField(blank=True, help_text='First day of the event', null=True),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='event_end_date',
            field=models.DateField(blank=True, help_text='Last day of the event', null=True),
        ),
    ]
