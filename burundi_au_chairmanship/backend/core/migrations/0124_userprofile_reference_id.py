"""Add persistent reference_id to UserProfile and backfill existing rows."""

from django.db import migrations, models


def backfill_reference_ids(apps, schema_editor):
    UserProfile = apps.get_model('core', 'UserProfile')
    profiles = UserProfile.objects.filter(reference_id='')
    for profile in profiles.iterator(chunk_size=500):
        profile.reference_id = f'B{profile.user_id:06d}'
        profile.save(update_fields=['reference_id'])


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0123_profanity_strike_log'),
    ]

    operations = [
        # 1. Add the field as blank, no unique constraint yet
        migrations.AddField(
            model_name='userprofile',
            name='reference_id',
            field=models.CharField(
                blank=True, default='', max_length=10,
                help_text='Unique reference number shown to user (e.g. B000001)',
            ),
        ),
        # 2. Backfill all existing profiles
        migrations.RunPython(backfill_reference_ids, migrations.RunPython.noop),
        # 3. Now enforce unique + index
        migrations.AlterField(
            model_name='userprofile',
            name='reference_id',
            field=models.CharField(
                blank=True, db_index=True, max_length=10, unique=True,
                help_text='Unique reference number shown to user (e.g. B000001)',
            ),
        ),
    ]
