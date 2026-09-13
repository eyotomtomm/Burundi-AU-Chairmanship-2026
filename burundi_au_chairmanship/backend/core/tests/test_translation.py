"""The parts of translation that must hold without a network call."""
from unittest import mock

from django.test import SimpleTestCase

from core import translation


class GuessLanguageTests(SimpleTestCase):
    def test_amharic_is_neither(self):
        # Translating these would write gibberish into the article.
        self.assertIsNone(translation.guess_language(
            'የብሩንዲ አምባሳደር ስለኢትዮጵያ ሪፎርም'))

    def test_provider_answer_is_used_when_it_is_en_or_fr(self):
        with mock.patch.object(translation, 'detect_language', return_value='fr'):
            self.assertEqual(translation.guess_language('Le sommet'), 'fr')

    def test_a_wrong_guess_falls_back_to_the_two_real_languages(self):
        # The provider calls short English headlines "rw" often enough that
        # skipping them would leave half the feed untranslated.
        with mock.patch.object(translation, 'detect_language', return_value='rw'):
            self.assertEqual(
                translation.guess_language(
                    "Minister Bizimana Meets with Sudan's Ambassador"), 'en')
            self.assertEqual(
                translation.guess_language(
                    'Le Ministre des Affaires Etrangères a reçu '
                    "l'Ambassadeur du Soudan"), 'fr')


class SplitTextTests(SimpleTestCase):
    def test_long_text_is_cut_on_sentence_boundaries(self):
        text = ('Burundi joined the meeting. ' * 40).strip()
        chunks = translation.split_text(text)
        self.assertGreater(len(chunks), 1)
        self.assertEqual(''.join(chunks), text)
        for chunk in chunks:
            self.assertLessEqual(len(chunk), translation.CHUNK)

    def test_short_text_is_one_piece(self):
        self.assertEqual(translation.split_text('Burundi.'), ['Burundi.'])


class TranslateTextTests(SimpleTestCase):
    def test_a_failed_chunk_gives_no_half_translation(self):
        # Half an article in each language reads as a bug to the reader.
        text = ('Burundi joined the meeting. ' * 40).strip()
        with mock.patch.object(translation, 'translate_chunk',
                               side_effect=['Le Burundi.', None]):
            self.assertIsNone(translation.translate_text(text, 'en', 'fr'))
