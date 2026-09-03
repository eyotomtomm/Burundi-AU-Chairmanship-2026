"""Checks for the discussion posting gate and media attachments.

Note: a fresh sqlite test DB can't be built here — migration 0136 uses
Postgres-only ``ADD COLUMN IF NOT EXISTS``. Run against a copy of the dev DB:

    DATABASES['default']['TEST'] = {'NAME': '<copy of db.sqlite3>'}
    python3 manage.py test core.test_discussion_media --keepdb
"""
import datetime
import shutil
import tempfile
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from .models import Discussion, DiscussionMedia


def _png():
    """Smallest valid PNG — passes the magic-byte check in validate_image_file."""
    data = (
        b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01'
        b'\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01'
        b'\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
    )
    return SimpleUploadedFile('shot.png', data, content_type='image/png')


_MEDIA = tempfile.mkdtemp()


@override_settings(MEDIA_ROOT=_MEDIA)
class DiscussionPostingTests(TestCase):
    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(_MEDIA, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            'youth', 'youth@example.com', 'pw', first_name='A', last_name='B')
        # The post_save signal already made the profile and cached it on the
        # user instance; reuse that object so force_authenticate sees the edits.
        self.profile = self.user.profile
        self.profile.is_email_verified = True
        self.profile.save()
        self.client.force_authenticate(self.user)

    def _complete_profile(self):
        self.profile.profile_picture = _png()
        self.profile.nationality = 'BI'
        self.profile.gender = 'male'
        self.profile.date_of_birth = datetime.date(2000, 1, 1)
        self.profile.phone_number = '+25700000000'
        # Posting also requires accepting the Explore community terms.
        self.profile.explore_terms_accepted_at = timezone.now()
        self.profile.save()

    def _post(self):
        return self.client.post('/api/discussions/', {
            'title': 'Water policy', 'content': 'Debate this', 'category': 'arise',
        })

    def test_incomplete_profile_cannot_post(self):
        resp = self._post()
        assert resp.status_code == 403, resp.status_code
        assert 'phone' in resp.data['missing_fields'], resp.data

    def test_complete_profile_can_post_to_arise(self):
        self._complete_profile()
        resp = self._post()
        assert resp.status_code == 201, resp.data
        assert Discussion.objects.get(pk=resp.data['id']).category == 'arise'

    def test_author_attaches_media_and_others_cannot(self):
        self._complete_profile()
        d = Discussion.objects.create(
            title='t', content='c', category='arise', author=self.user)

        resp = self.client.post(f'/api/discussions/{d.pk}/media/',
                                {'file': _png(), 'media_type': 'image'}, format='multipart')
        assert resp.status_code == 201, resp.data
        assert resp.data['url'], resp.data
        assert d.media.count() == 1

        # Media rides along on the detail payload the app reads.
        detail = self.client.get(f'/api/discussions/{d.pk}/')
        assert len(detail.data['media']) == 1, detail.data

        other = User.objects.create_user('other', 'o@example.com', 'pw', first_name='O')
        other.profile.is_email_verified = True
        other.profile.save()
        self.client.force_authenticate(other)
        resp = self.client.post(f'/api/discussions/{d.pk}/media/',
                                {'file': _png(), 'media_type': 'image'}, format='multipart')
        assert resp.status_code == 403, resp.status_code

    def test_attachment_cap_enforced(self):
        self._complete_profile()
        d = Discussion.objects.create(
            title='t', content='c', category='arise', author=self.user)
        for _ in range(DiscussionMedia.MAX_PER_DISCUSSION):
            resp = self.client.post(f'/api/discussions/{d.pk}/media/',
                                    {'file': _png(), 'media_type': 'image'}, format='multipart')
            assert resp.status_code == 201, resp.data
        resp = self.client.post(f'/api/discussions/{d.pk}/media/',
                                {'file': _png(), 'media_type': 'image'}, format='multipart')
        assert resp.status_code == 400, resp.status_code

    def test_bogus_file_rejected(self):
        self._complete_profile()
        d = Discussion.objects.create(
            title='t', content='c', category='arise', author=self.user)
        fake = SimpleUploadedFile('evil.png', b'not really a png', content_type='image/png')
        resp = self.client.post(f'/api/discussions/{d.pk}/media/',
                                {'file': fake, 'media_type': 'image'}, format='multipart')
        assert resp.status_code == 400, resp.status_code
        assert d.media.count() == 0
