"""
Migration C: Enforce constraints for Youth Dialogue multi-event.

- Make slug unique on YouthDialogueEvent
- Make Application.event non-nullable (all rows backfilled in migration B)
- Add UniqueConstraint(user, event) on YouthDialogueApplication
"""
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0118_youth_dialogue_multi_event_data'),
    ]

    operations = [
        # 1. Make slug unique
        migrations.AlterField(
            model_name='youthdialogueevent',
            name='slug',
            field=models.SlugField(
                max_length=120,
                unique=True,
                help_text='URL-friendly identifier (e.g. yd-bujumbura-june-2026)',
            ),
        ),

        # 2. Make event non-nullable (data migration already backfilled all rows)
        migrations.AlterField(
            model_name='youthdialogueapplication',
            name='event',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name='applications',
                to='core.youthdialogueevent',
            ),
        ),

        # 3. Add unique constraint: one application per user per event
        migrations.AddConstraint(
            model_name='youthdialogueapplication',
            constraint=models.UniqueConstraint(
                fields=['user', 'event'],
                name='unique_user_event_application',
            ),
        ),
    ]
