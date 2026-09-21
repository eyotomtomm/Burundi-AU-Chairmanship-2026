from django.contrib.auth.models import AnonymousUser, User
from django.test import RequestFactory, TestCase

from core.models import EventRegistration, detect_stream_platform
from core.serializers import EventRegistrationSerializer


class MeetingLinkVisibilityTests(TestCase):
    """The joining link is for signed-in users; a guest is only told it exists."""

    def setUp(self):
        self.reg = EventRegistration.objects.create(
            event_title='Summit', event_type='online',
            meeting_url='https://meet.google.com/abc-defg-hij',
        )

    def _meeting_for(self, user):
        request = RequestFactory().get('/')
        request.user = user
        return EventRegistrationSerializer(self.reg, context={'request': request}).data['meeting']

    def test_guest_is_told_to_sign_in_and_gets_no_link(self):
        meeting = self._meeting_for(AnonymousUser())
        self.assertEqual(meeting, {'requires_sign_in': True})

    def test_signed_in_user_gets_the_link_and_platform(self):
        user = User.objects.create_user('someone', 'a@b.com', 'pw')
        meeting = self._meeting_for(user)
        self.assertFalse(meeting['requires_sign_in'])
        self.assertEqual(meeting['url'], 'https://meet.google.com/abc-defg-hij')
        self.assertEqual(meeting['platform'], 'meet')

    def test_in_person_event_has_no_meeting(self):
        self.reg.event_type = 'in_person'
        self.reg.save()
        user = User.objects.create_user('other', 'c@d.com', 'pw')
        self.assertIsNone(self._meeting_for(user))

    def test_online_event_without_a_link_has_no_meeting(self):
        self.reg.meeting_url = ''
        self.reg.save()
        user = User.objects.create_user('third', 'e@f.com', 'pw')
        self.assertIsNone(self._meeting_for(user))

    def test_platform_detection_covers_the_meeting_apps(self):
        self.assertEqual(detect_stream_platform('https://meet.google.com/x'), 'meet')
        self.assertEqual(detect_stream_platform('https://zoom.us/j/1'), 'zoom')
        self.assertEqual(detect_stream_platform('https://teams.microsoft.com/l/x'), 'teams')
        self.assertEqual(detect_stream_platform(''), 'video')
