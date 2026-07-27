"""
Backfill empty nationality fields on YouthDialogueApplication records.

Some applications stored the nationality in additional_data (under keys like
"country", "pays", "nationalite") instead of the model column.  This command
reads those values, resolves them to ISO codes, and writes them back to the
nationality column.

Usage:
    python manage.py backfill_yd_nationality
    python manage.py backfill_yd_nationality --dry-run
"""
from django.core.management.base import BaseCommand
from core.models import NATIONALITY_CHOICES, YouthDialogueApplication


# Keys in additional_data that may contain a nationality value
_COUNTRY_KEYS = ('nationality', 'country', 'pays', 'nationalite', 'country_of_origin')

# Lookup tables
_CODE_SET = {code for code, _ in NATIONALITY_CHOICES}           # valid ISO codes
_NAME_TO_CODE = {name.lower(): code for code, name in NATIONALITY_CHOICES}  # name → code


def _resolve_code(value):
    """Normalize a nationality value (ISO code or country name) to an ISO code."""
    if not value:
        return ''
    val = str(value).strip()
    upper = val.upper()
    if upper in _CODE_SET:
        return upper
    return _NAME_TO_CODE.get(val.lower(), '')


class Command(BaseCommand):
    help = 'Backfill empty nationality on YouthDialogueApplication from additional_data'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be updated without making changes',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']

        apps = YouthDialogueApplication.objects.filter(nationality='')
        updated = 0

        for app in apps:
            ad = app.additional_data
            if not isinstance(ad, dict):
                continue

            resolved = ''
            matched_key = ''
            for key in _COUNTRY_KEYS:
                val = ad.get(key)
                if val:
                    resolved = _resolve_code(val)
                    if resolved:
                        matched_key = key
                        break

            if not resolved:
                continue

            name = f'{app.first_name} {app.last_name}'.strip() or f'App #{app.pk}'

            if dry_run:
                self.stdout.write(
                    f'  [DRY RUN] {name}: '
                    f'additional_data["{matched_key}"] = "{ad[matched_key]}" → {resolved}'
                )
            else:
                app.nationality = resolved
                app.save(update_fields=['nationality'])
                self.stdout.write(self.style.SUCCESS(
                    f'  {name}: '
                    f'additional_data["{matched_key}"] = "{ad[matched_key]}" → {resolved}'
                ))

            updated += 1

        action = 'Would update' if dry_run else 'Updated'
        self.stdout.write(self.style.SUCCESS(
            f'\n{action} {updated} application(s).'
        ))
