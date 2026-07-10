from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0145_youthdialoguedeviceban'),
    ]

    operations = [
        migrations.AddField(
            model_name='appsettings',
            name='qr_scanner_title',
            field=models.CharField(blank=True, default='QR Scanner', help_text='QR Scanner quick access title (English)', max_length=100),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='qr_scanner_title_fr',
            field=models.CharField(blank=True, default='Scanner QR', help_text='QR Scanner quick access title (French)', max_length=100),
        ),
    ]
