import core.validators
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0124_userprofile_reference_id'),
    ]

    operations = [
        migrations.AddField(
            model_name='youthdialogueevent',
            name='banner_image',
            field=models.ImageField(blank=True, help_text='Hero banner image for the landing page', null=True, upload_to='youth_dialogue/banners/', validators=[core.validators.validate_image_file]),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='event_tagline',
            field=models.CharField(blank=True, default='', help_text='Short tagline shown below title', max_length=300),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='event_tagline_fr',
            field=models.CharField(blank=True, default='', max_length=300),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='venue_name',
            field=models.CharField(blank=True, default='', help_text='Venue name (e.g. Palais des Congrès)', max_length=200),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='venue_name_fr',
            field=models.CharField(blank=True, default='', max_length=200),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='venue_address',
            field=models.TextField(blank=True, default='', help_text='Full venue address'),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='venue_address_fr',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='key_highlights',
            field=models.TextField(blank=True, default='', help_text='One highlight per line (EN)'),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='key_highlights_fr',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='eligibility_criteria',
            field=models.TextField(blank=True, default='', help_text='One criterion per line (EN)'),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='eligibility_criteria_fr',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='side_events_info',
            field=models.TextField(blank=True, default='', help_text='One side event per line (EN) — format: Title | Description'),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='side_events_info_fr',
            field=models.TextField(blank=True, default=''),
        ),
    ]
