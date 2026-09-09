from django import template

register = template.Library()


@register.filter
def is_image_url(url):
    """True when the URL path ends in a browser-renderable image extension."""
    path = (url or '').split('?')[0].lower()
    return path.endswith(('.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'))


@register.filter
def safe_image_url(image_field):
    """Safely resolve an ImageField URL without crashing if S3 is misconfigured."""
    if not image_field:
        return ''
    try:
        return image_field.url
    except Exception:
        return ''
