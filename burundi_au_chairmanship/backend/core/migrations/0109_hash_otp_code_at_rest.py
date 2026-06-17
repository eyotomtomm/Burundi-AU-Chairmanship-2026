import hashlib

from django.db import migrations, models


def hash_existing_otps(apps, schema_editor):
    """One-shot migration: SHA-256 hash every plaintext OTP still in the table.

    Already-hashed rows (64 hex chars) are skipped so the migration is
    safe to re-run.
    """
    OTPVerification = apps.get_model('core', 'OTPVerification')
    for otp in OTPVerification.objects.all().iterator():
        if len(otp.otp_code) == 64:
            continue  # already looks like a SHA-256 hex digest
        otp.otp_code = hashlib.sha256(otp.otp_code.encode()).hexdigest()
        otp.save(update_fields=['otp_code'])


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0108_scheduledmaintenance_ends_at_nullable'),
    ]

    operations = [
        migrations.AlterField(
            model_name='otpverification',
            name='otp_code',
            field=models.CharField(
                help_text='SHA-256 hash of the OTP code',
                max_length=64,
            ),
        ),
        migrations.RunPython(hash_existing_otps, migrations.RunPython.noop),
    ]
