"""
Migration A: Youth Dialogue multi-event schema changes.

- Rename YouthDialogueSettings -> YouthDialogueEvent
- Add event identity fields: slug, is_active, location, start_date, end_date, created_at
- Add event FK on YouthDialogueApplication (nullable for now)
- Change Application.user from OneToOneField to ForeignKey
- Add event FK on YouthDialogueActivityLog
"""
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('core', '0116_qr_scan_log_and_qr_code_mode'),
    ]

    operations = [
        # 1. Rename the model (Python-level only — db_table stays 'core_youthdialoguesettings')
        migrations.RenameModel(
            old_name='YouthDialogueSettings',
            new_name='YouthDialogueEvent',
        ),

        # 2. Add new event identity fields
        migrations.AddField(
            model_name='youthdialogueevent',
            name='slug',
            field=models.SlugField(
                max_length=120, default='youth-dialogue-default',
                help_text='URL-friendly identifier (e.g. yd-bujumbura-june-2026)',
            ),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='is_active',
            field=models.BooleanField(
                default=False,
                help_text='Only one event can be active at a time — the Flutter app serves the active event',
            ),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='location',
            field=models.CharField(
                max_length=200, blank=True, default='',
                help_text='Event location (e.g. Bujumbura, Burundi)',
            ),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='start_date',
            field=models.DateField(null=True, blank=True, help_text='Event start date'),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='end_date',
            field=models.DateField(null=True, blank=True, help_text='Event end date'),
        ),
        migrations.AddField(
            model_name='youthdialogueevent',
            name='created_at',
            field=models.DateTimeField(auto_now_add=True, default='2026-01-01T00:00:00Z'),
            preserve_default=False,
        ),

        # 3. Add event FK to YouthDialogueApplication (nullable initially)
        migrations.AddField(
            model_name='youthdialogueapplication',
            name='event',
            field=models.ForeignKey(
                to='core.YouthDialogueEvent',
                on_delete=django.db.models.deletion.CASCADE,
                related_name='applications',
                null=True,
            ),
        ),

        # 4. Change Application.user from OneToOneField to ForeignKey
        migrations.AlterField(
            model_name='youthdialogueapplication',
            name='user',
            field=models.ForeignKey(
                to=settings.AUTH_USER_MODEL,
                on_delete=django.db.models.deletion.CASCADE,
                related_name='youth_dialogue_applications',
            ),
        ),

        # 5. Add event FK to YouthDialogueActivityLog
        migrations.AddField(
            model_name='youthdialogueactivitylog',
            name='event',
            field=models.ForeignKey(
                to='core.YouthDialogueEvent',
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='activity_logs',
                null=True,
                blank=True,
            ),
        ),

        # 6. Add ordering to YouthDialogueEvent
        migrations.AlterModelOptions(
            name='youthdialogueevent',
            options={
                'ordering': ['-created_at'],
                'verbose_name': 'Youth Dialogue Event',
                'verbose_name_plural': 'Youth Dialogue Events',
            },
        ),

        # 7. Set db_table to preserve existing table name
        migrations.AlterModelTable(
            name='youthdialogueevent',
            table='core_youthdialoguesettings',
        ),
    ]
