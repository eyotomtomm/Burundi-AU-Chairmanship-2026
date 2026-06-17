from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('core', '0115_event_registration_ordering_by_date'),
    ]

    operations = [
        # Add qr_code_mode to AppSettings
        migrations.AddField(
            model_name='appsettings',
            name='qr_code_mode',
            field=models.CharField(
                choices=[('url', 'URL (opens web verification page)'), ('raw', 'Raw (in-app scanner only)')],
                default='url',
                help_text='How QR codes encode data: "url" embeds a web verification link; "raw" embeds just the token',
                max_length=5,
            ),
        ),
        # Create QRScanLog model
        migrations.CreateModel(
            name='QRScanLog',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('qr_type', models.CharField(choices=[('event', 'Event Ticket'), ('youth_dialogue', 'Youth Dialogue Credential')], max_length=20)),
                ('reference_id', models.CharField(db_index=True, help_text='Submission ID or participant code', max_length=100)),
                ('scanned_at', models.DateTimeField(auto_now_add=True)),
                ('ip_address', models.GenericIPAddressField(blank=True, null=True)),
                ('is_duplicate', models.BooleanField(default=False)),
                ('scanned_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='qr_scans', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'QR Scan Log',
                'verbose_name_plural': 'QR Scan Logs',
                'ordering': ['-scanned_at'],
                'indexes': [
                    models.Index(fields=['qr_type', 'reference_id'], name='core_qrscan_qr_type_ref_idx'),
                ],
            },
        ),
    ]
