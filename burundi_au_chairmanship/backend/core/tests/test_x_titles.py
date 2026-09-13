"""Imported X posts are read as headlines, so the title has to survive the
timeline markup: tags are words, handles are people, credit dumps are noise."""
from django.test import SimpleTestCase

from core.management.commands.import_x_posts import clean_prose, make_title


class MakeTitleTests(SimpleTestCase):
    def test_leading_hashtag_stays_a_word(self):
        # Deleting the tag used to leave "joins the African Union family…".
        title = make_title('#Burundi joins the African Union family on September 9. '
                           'A moment to reflect.')
        self.assertEqual(
            title, 'Burundi joins the African Union family on September 9.')

    def test_credit_dump_is_not_the_title(self):
        title = make_title('It is time to say: «MURAKOZE»\n\n'
                           '@NtareHouse @OPDD_Burundi @MinJSCBdi\n@UN_Burundi')
        self.assertEqual(title, 'It is time to say: «MURAKOZE»')

    def test_lone_handle_becomes_the_person(self):
        title = make_title(
            'H.E. Ambassador @willynyamitwe , Permanent Representative of '
            '#Burundi, chaired the session.',
            mentions=[{'name': 'willynyamitwe', 'nick': 'Amb. Willy Nyamitwe'}],
        )
        self.assertEqual(
            title,
            'H.E. Ambassador Willy Nyamitwe, Permanent Representative of '
            'Burundi, chaired the session.')

    def test_abbreviation_does_not_end_the_sentence(self):
        self.assertEqual(
            make_title('Held today: H.E. the Minister opened the forum. '
                       'Delegates followed.'),
            'Held today: H.E. the Minister opened the forum.')

    def test_long_title_is_cut_on_a_word_boundary(self):
        title = make_title('Le lancement des lignes directrices continentales '
                           'sur la diplomatie numérique africaine ' + 'très ' * 60)
        self.assertEqual(len(title) <= 201, True)
        self.assertTrue(title.endswith('…'))
        self.assertNotIn('tr…', title)

    def test_links_and_newlines_leave_no_gaps(self):
        self.assertEqual(
            clean_prose('[LIVE NOW]\nOpening Ceremony https://x.com/i/broadcasts/1PK'),
            '[LIVE NOW] Opening Ceremony')

    def test_rank_does_not_end_the_sentence(self):
        # "…African Union, H.E. Gen." was shipped as a whole headline.
        title = make_title(
            'Burundi’s President and Chairperson of the African Union, '
            'H.E. Gen. Évariste Ndayishimiye arrived in New Delhi.')
        # A sentence this length is still a headline; it must arrive whole.
        self.assertTrue(title.endswith('arrived in New Delhi.'), title)

    def test_paragraph_sentence_is_cut_to_a_headline(self):
        # The whole story used to land in the title with nothing left to read.
        title = make_title(
            'Lors des échanges sur les travaux de la CVR BURUNDI, à '
            'l’Ambassade du Burundi à Addis-Abeba, M. Salvator Nkeshimana, '
            'Vice-Président de la Communauté Burundaise, a souligné la '
            'nécessité de faire connaître le rapport.')
        self.assertLessEqual(len(title), 130)
        self.assertFalse(title.endswith('…'))
        self.assertTrue(title.startswith('Lors des échanges'), title)

    def test_tagged_account_beside_the_name_is_dropped(self):
        # "H.E. Ndayishimiye (SE Evariste Ndayishimiye)" named him twice.
        title = make_title(
            'Arrival of H.E. Évariste Ndayishimiye (@GeneralNeva) in New Delhi.',
            mentions=[{'name': 'GeneralNeva', 'nick': 'SE Evariste Ndayishimiye'}],
        )
        self.assertEqual(title, 'Arrival of H.E. Évariste Ndayishimiye in New Delhi.')

    def test_account_branding_leaves_the_person(self):
        title = make_title(
            'Minister @MFABurundi was received at the airport in New Delhi.',
            mentions=[{'name': 'MFABurundi', 'nick': 'Edouard Bizimana/ MoFA 🇧🇮'}],
        )
        self.assertEqual(
            title, 'Minister Edouard Bizimana was received at the airport in New Delhi.')
