# Data migration to seed default email templates

from django.db import migrations


def _email_wrapper(content):
    """Wrap email content in a responsive HTML template with green branding."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Burundi Chairmanship</title>
</head>
<body style="margin:0;padding:0;background-color:#f4f7fa;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">
<table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background-color:#f4f7fa;">
<tr><td align="center" style="padding:40px 20px;">
<table role="presentation" cellpadding="0" cellspacing="0" width="600" style="max-width:600px;background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">
<!-- Header -->
<tr><td style="background:linear-gradient(135deg,#1B5E20 0%,#2E7D32 100%);padding:32px 40px;text-align:center;">
<h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700;letter-spacing:0.5px;">Burundi Chairmanship</h1>
<p style="margin:6px 0 0;color:rgba(255,255,255,0.8);font-size:12px;text-transform:uppercase;letter-spacing:2px;">2026 - 2027</p>
</td></tr>
<!-- Content -->
<tr><td style="padding:40px;">
{content}
</td></tr>
<!-- Footer -->
<tr><td style="background-color:#f8faf8;padding:24px 40px;text-align:center;border-top:1px solid #e8f0e8;">
<p style="margin:0;color:#6b7280;font-size:12px;">{{{{ app_name }}}}</p>
<p style="margin:8px 0 0;color:#9ca3af;font-size:11px;">Bujumbura, Burundi &bull; burundi4africa.com</p>
<p style="margin:12px 0 0;color:#9ca3af;font-size:10px;">This is an automated message. Please do not reply directly.</p>
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>"""


def seed_email_templates(apps, schema_editor):
    EmailTemplate = apps.get_model('core', 'EmailTemplate')

    # Only seed if the table is empty
    if EmailTemplate.objects.exists():
        return

    templates = [
        {
            'key': 'welcome',
            'subject': 'Welcome to Burundi Chairmanship',
            'subject_fr': 'Bienvenue au Burundi Presidence de l\'UA',
            'body_html': _email_wrapper("""
<h2 style="margin:0 0 16px;color:#1B5E20;font-size:24px;font-weight:700;">Welcome, {{{{ username }}}}!</h2>
<p style="color:#374151;font-size:15px;line-height:1.7;margin:0 0 20px;">
Thank you for joining the Burundi Chairmanship app. We are delighted to have you as part of our community.
</p>
<p style="color:#374151;font-size:15px;line-height:1.7;margin:0 0 24px;">
Stay informed about the latest events, news, and initiatives during Burundi's historic chairmanship of the African Union.
</p>
<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
<tr><td style="background-color:#1B5E20;border-radius:8px;">
<a href="{{{{ action_url }}}}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:600;font-size:15px;">Explore the App</a>
</td></tr>
</table>
<p style="color:#6b7280;font-size:13px;line-height:1.6;margin:24px 0 0;">
If you have any questions, feel free to reach out to our support team through the app.
</p>"""),
            'body_html_fr': '',
            'body_text': 'Welcome to Burundi Chairmanship, {{ username }}! Thank you for joining our community.',
            'body_text_fr': '',
            'is_active': True,
        },
        {
            'key': 'verification_approved',
            'subject': 'Your Account Has Been Verified',
            'subject_fr': 'Votre compte a ete verifie',
            'body_html': _email_wrapper("""
<h2 style="margin:0 0 16px;color:#1B5E20;font-size:24px;font-weight:700;">Congratulations, {{{{ username }}}}!</h2>
<p style="color:#374151;font-size:15px;line-height:1.7;margin:0 0 20px;">
Your account verification has been approved. You have been awarded the <strong style="color:#1B5E20;">{{{{ badge_type }}}} Badge</strong>.
</p>
<div style="background-color:#f0fdf4;border:1px solid #bbf7d0;border-radius:8px;padding:20px;text-align:center;margin:0 0 24px;">
<p style="margin:0;font-size:36px;">&#9989;</p>
<p style="margin:8px 0 0;color:#15803d;font-weight:700;font-size:16px;">Verified Account</p>
<p style="margin:4px 0 0;color:#16a34a;font-size:13px;">{{{{ badge_type }}}} Badge Holder</p>
</div>
<p style="color:#374151;font-size:15px;line-height:1.7;margin:0 0 24px;">
You now have access to enhanced features and your profile will display the verification badge.
</p>
<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
<tr><td style="background-color:#1B5E20;border-radius:8px;">
<a href="{{{{ action_url }}}}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:600;font-size:15px;">View Your Profile</a>
</td></tr>
</table>"""),
            'body_html_fr': '',
            'body_text': 'Congratulations {{ username }}! Your account has been verified with {{ badge_type }} Badge.',
            'body_text_fr': '',
            'is_active': True,
        },
        {
            'key': 'password_reset',
            'subject': 'Reset Your Password',
            'subject_fr': 'Reinitialiser votre mot de passe',
            'body_html': _email_wrapper("""
<h2 style="margin:0 0 16px;color:#1B5E20;font-size:24px;font-weight:700;">Password Reset Request</h2>
<p style="color:#374151;font-size:15px;line-height:1.7;margin:0 0 12px;">
Hello {{{{ username }}}},
</p>
<p style="color:#374151;font-size:15px;line-height:1.7;margin:0 0 24px;">
We received a request to reset your password. Click the button below to create a new password. This link will expire in {{{{ expiry_minutes }}}} minutes.
</p>
<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto 24px;">
<tr><td style="background-color:#1B5E20;border-radius:8px;">
<a href="{{{{ reset_link }}}}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:600;font-size:15px;">Reset Password</a>
</td></tr>
</table>
<p style="color:#6b7280;font-size:13px;line-height:1.6;margin:0 0 12px;">
If you did not request this password reset, please ignore this email. Your password will remain unchanged.
</p>
<p style="color:#9ca3af;font-size:12px;line-height:1.5;margin:0;">
If the button does not work, copy and paste this link into your browser:<br>
<span style="color:#2563eb;word-break:break-all;">{{{{ reset_link }}}}</span>
</p>"""),
            'body_html_fr': '',
            'body_text': 'Hello {{ username }}, we received a password reset request. Visit this link: {{ reset_link }}',
            'body_text_fr': '',
            'is_active': True,
        },
        {
            'key': 'event_reminder',
            'subject': 'Event Starting Soon: {{ event_name }}',
            'subject_fr': 'Evenement imminent: {{ event_name }}',
            'body_html': _email_wrapper("""
<h2 style="margin:0 0 16px;color:#1B5E20;font-size:24px;font-weight:700;">Event Reminder</h2>
<p style="color:#374151;font-size:15px;line-height:1.7;margin:0 0 20px;">
Hello {{{{ username }}}},
</p>
<p style="color:#374151;font-size:15px;line-height:1.7;margin:0 0 24px;">
This is a friendly reminder that the following event is starting soon:
</p>
<div style="background-color:#f0fdf4;border-left:4px solid #1B5E20;border-radius:0 8px 8px 0;padding:20px;margin:0 0 24px;">
<h3 style="margin:0 0 8px;color:#1B5E20;font-size:18px;font-weight:700;">{{{{ event_name }}}}</h3>
<p style="margin:0;color:#374151;font-size:14px;">
<strong>Date:</strong> {{{{ event_date }}}}<br>
</p>
</div>
<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
<tr><td style="background-color:#1B5E20;border-radius:8px;">
<a href="{{{{ action_url }}}}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:600;font-size:15px;">View Event Details</a>
</td></tr>
</table>
<p style="color:#6b7280;font-size:13px;line-height:1.6;margin:24px 0 0;">
We look forward to seeing you there!
</p>"""),
            'body_html_fr': '',
            'body_text': 'Hello {{ username }}, reminder: {{ event_name }} is on {{ event_date }}.',
            'body_text_fr': '',
            'is_active': True,
        },
    ]

    for tmpl_data in templates:
        try:
            EmailTemplate.objects.create(**tmpl_data)
        except Exception:
            # Skip if key already exists (e.g., unique constraint)
            pass


def reverse_seed(apps, schema_editor):
    EmailTemplate = apps.get_model('core', 'EmailTemplate')
    EmailTemplate.objects.filter(
        key__in=['welcome', 'verification_approved', 'password_reset', 'event_reminder']
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0069_usersegment_databasebackup_adminnotification_and_more'),
    ]

    operations = [
        migrations.RunPython(seed_email_templates, reverse_seed),
    ]
