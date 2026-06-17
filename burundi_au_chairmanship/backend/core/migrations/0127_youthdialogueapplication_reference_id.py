from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0126_add_privacy_policy_to_youth_dialogue'),
    ]

    operations = [
        migrations.AddField(
            model_name='youthdialogueapplication',
            name='reference_id',
            field=models.CharField(
                blank=True,
                db_index=True,
                help_text='Auto-generated application reference (e.g. YD-2026-00042)',
                max_length=20,
                null=True,
                unique=True,
            ),
        ),
    ]
