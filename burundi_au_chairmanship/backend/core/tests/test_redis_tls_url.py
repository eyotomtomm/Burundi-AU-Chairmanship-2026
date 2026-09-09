"""DigitalOcean hands out rediss:// URLs; kombu rejects them without
ssl_cert_reqs, which would crash-loop the Celery worker on boot."""
import importlib
import os
from unittest.mock import patch

from django.test import SimpleTestCase


def _redis_url_for(value):
    """Re-read settings with REDIS_URL set to `value`."""
    with patch.dict(os.environ, {'REDIS_URL': value}):
        mod = importlib.import_module('config.settings')
        importlib.reload(mod)
        url = mod.REDIS_URL
        broker = mod.CELERY_BROKER_URL
    importlib.reload(mod)  # restore the real settings for other tests
    return url, broker


class RedisTlsUrlTests(SimpleTestCase):
    def test_tls_url_gains_ssl_cert_reqs(self):
        url, broker = _redis_url_for('rediss://user:pw@db.ondigitalocean.com:25061')
        self.assertIn('ssl_cert_reqs=none', url)
        self.assertTrue(url.startswith('rediss://'))
        # Celery reads the same URL, so the worker boots too.
        self.assertIn('ssl_cert_reqs=none', broker)

    def test_existing_query_string_is_preserved(self):
        url, _ = _redis_url_for('rediss://h:1/0?foo=bar')
        self.assertIn('foo=bar', url)
        self.assertIn('&ssl_cert_reqs=none', url)

    def test_explicit_setting_is_not_overridden(self):
        url, _ = _redis_url_for('rediss://h:1/0?ssl_cert_reqs=required')
        self.assertIn('ssl_cert_reqs=required', url)
        self.assertNotIn('none', url)

    def test_plain_redis_url_is_untouched(self):
        url, _ = _redis_url_for('redis://localhost:6379/1')
        self.assertEqual(url, 'redis://localhost:6379/1')
