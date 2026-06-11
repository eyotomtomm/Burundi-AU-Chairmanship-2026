from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0107_promotionalsplash'),
    ]

    operations = [
        migrations.AlterField(
            model_name='scheduledmaintenance',
            name='ends_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                help_text='Leave empty for indefinite maintenance (turn off manually)',
            ),
        ),
    ]
