from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0140_about_page_editable'),
    ]

    operations = [
        migrations.AddField(
            model_name='quickaccessmenuitem',
            name='icon_image',
            field=models.ImageField(
                blank=True,
                null=True,
                upload_to='quick_access_icons/',
                help_text='Custom icon image. Takes priority over icon_name.',
            ),
        ),
        migrations.AlterField(
            model_name='quickaccessmenuitem',
            name='icon_name',
            field=models.CharField(
                max_length=50,
                blank=True,
                help_text='Flutter icon name (e.g. live_tv, menu_book, article). Ignored when icon_image is set.',
            ),
        ),
    ]
