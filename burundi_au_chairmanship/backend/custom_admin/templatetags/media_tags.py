from django import template

register = template.Library()


@register.filter
def safe_image_url(image_field):
    """Safely resolve an ImageField URL without crashing if S3 is misconfigured."""
    if not image_field:
        return ''
    try:
        return image_field.url
    except Exception:
        return ''
