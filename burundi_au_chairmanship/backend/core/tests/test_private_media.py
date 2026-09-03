"""Private uploads (verification documents, ID photos, support attachments) must
never be handed out as unsigned URLs, including when the media CDN is enabled."""

from django.test import SimpleTestCase, override_settings

from config.storage_backends import PrivateSpacesMediaStorage, SpacesMediaStorage


class PrivateStorageUrlTests(SimpleTestCase):
    @override_settings(
        AWS_S3_CUSTOM_DOMAIN='burundi-au-media.fra1.cdn.digitaloceanspaces.com',
        AWS_ACCESS_KEY_ID='test-key',
        AWS_SECRET_ACCESS_KEY='test-secret',
        AWS_STORAGE_BUCKET_NAME='burundi-au-media',
        AWS_S3_ENDPOINT_URL='https://fra1.digitaloceanspaces.com',
    )
    def test_private_urls_stay_signed_when_cdn_is_enabled(self):
        url = PrivateSpacesMediaStorage().url('verification_documents/passport.jpg')
        signed = 'X-Amz-Signature' in url or 'Signature=' in url
        self.assertTrue(signed, f'private media URL was not signed: {url}')
        self.assertNotIn('cdn.digitaloceanspaces.com', url,
                         'private media must not be served through the CDN')

    @override_settings(
        AWS_S3_CUSTOM_DOMAIN='burundi-au-media.fra1.cdn.digitaloceanspaces.com',
        AWS_STORAGE_BUCKET_NAME='burundi-au-media',
        AWS_S3_ENDPOINT_URL='https://fra1.digitaloceanspaces.com',
    )
    def test_public_media_still_uses_the_cdn(self):
        url = SpacesMediaStorage().url('articles/photo.webp')
        self.assertIn('cdn.digitaloceanspaces.com', url)
