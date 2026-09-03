"""Share links must resolve for every kind, hide unpublished items, and
hand chat apps a JPEG preview rather than the stored WebP."""
from django.test import TestCase
from django.utils import timezone

from core.models import Article, EventRegistration, Fact, FactCategory


class ShareCardTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.article = Article.objects.create(
            title='Chairmanship opens',
            title_fr='La présidence ouvre',
            content='<p>Body <b>text</b> here.</p>',
            content_fr='<p>Texte en français.</p>',
            publish_date=timezone.now(),
            status='published',
        )
        cls.draft = Article.objects.create(
            title='Not ready', content='secret', publish_date=timezone.now(), status='draft',
        )
        cls.event = EventRegistration.objects.create(event_title='Summit day')
        cls.fact = Fact.objects.create(
            title='Did You Know?',
            content='Burundi chairs the African Union.',
            category=FactCategory.objects.create(name='General'),
        )

    def test_share_page_carries_og_tags_pointing_at_the_card(self):
        res = self.client.get(f'/articles/{self.article.pk}/share/')
        self.assertEqual(res.status_code, 200)
        body = res.content.decode()
        self.assertIn('Chairmanship opens', body)
        self.assertIn(f'/articles/{self.article.pk}/card.jpg', body)
        self.assertIn('og:image:width', body)
        self.assertNotIn('<b>', body)  # HTML in the source content is stripped.

    def test_french_link_uses_the_french_copy(self):
        res = self.client.get(f'/articles/{self.article.pk}/share/', {'lang': 'fr'})
        self.assertIn('La présidence ouvre', res.content.decode())

    def test_unpublished_content_is_not_shareable(self):
        self.assertEqual(self.client.get(f'/articles/{self.draft.pk}/share/').status_code, 404)
        self.assertEqual(self.client.get(f'/articles/{self.draft.pk}/card.jpg').status_code, 404)

    def test_card_renders_as_jpeg_for_every_kind(self):
        for path in (
            f'/articles/{self.article.pk}/card.jpg',
            f'/events/{self.event.pk}/card.jpg',
            f'/facts/{self.fact.pk}/card.jpg',
        ):
            with self.subTest(path=path):
                res = self.client.get(path)
                self.assertEqual(res.status_code, 200)
                self.assertEqual(res['Content-Type'], 'image/jpeg')
                self.assertTrue(res.content.startswith(b'\xff\xd8'))

    def test_fact_card_headline_falls_back_to_its_body(self):
        # "Did You Know?" is a useless headline; the fact itself is the news.
        res = self.client.get(f'/facts/{self.fact.pk}/share/')
        self.assertIn('Burundi chairs the African Union.', res.content.decode())

    def test_every_share_kind_names_a_real_model_and_fields(self):
        # A typo here is invisible until someone shares that kind and gets a 404,
        # which is how `events` once pointed at the wrong model entirely.
        from core import views

        for kind, (model_name, title, body, image, labels) in views.SHARE_KINDS.items():
            with self.subTest(kind=kind):
                model = getattr(views, model_name, None)
                self.assertIsNotNone(model, f'{kind}: no model {model_name}')
                names = {f.name for f in model._meta.get_fields()}
                self.assertIn(title, names)
                self.assertIn(body, names)
                if image is not None:
                    self.assertIn(image, names)
                self.assertEqual(len(labels), 2)

    def test_unknown_kind_is_rejected(self):
        self.assertEqual(self.client.get('/widgets/1/share/').status_code, 404)
