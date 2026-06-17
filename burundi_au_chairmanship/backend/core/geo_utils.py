import logging
import os
from django.conf import settings

logger = logging.getLogger(__name__)

_geoip_reader = None


def get_geoip_reader():
    """Lazy-load singleton GeoIP2 reader."""
    global _geoip_reader
    if _geoip_reader is not None:
        return _geoip_reader

    try:
        import geoip2.database
        db_path = os.path.join(settings.GEOIP_PATH, settings.GEOIP_CITY)
        if os.path.exists(db_path):
            _geoip_reader = geoip2.database.Reader(db_path)
            logger.info('GeoIP2 database loaded from %s', db_path)
        else:
            logger.warning('GeoIP2 database not found at %s', db_path)
    except ImportError:
        logger.warning('geoip2 package not installed')
    except Exception as e:
        logger.error('Failed to load GeoIP2 database: %s', e)

    return _geoip_reader


def get_country_from_ip(ip_address):
    """
    Returns (country_code, country_name, city) from IP address.
    Returns ('', '', '') if lookup fails.
    """
    reader = get_geoip_reader()
    if reader is None:
        return ('', '', '')

    try:
        response = reader.city(ip_address)
        country_code = response.country.iso_code or ''
        country_name = response.country.name or ''
        city = response.city.name or ''
        return (country_code, country_name, city)
    except Exception:
        return ('', '', '')


def get_client_ip(request):
    """Extract the real client IP (REMOTE_ADDR, already set by CloudflareProxyMiddleware)."""
    return request.META.get('REMOTE_ADDR', '')
