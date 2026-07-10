"""
Import news articles from Burundi Ministry of Foreign Affairs (MAE) website.

Creates Article objects for diplomatic news from May 21 – July 10, 2026,
sourced from https://www.mae.gov.bi/en/category/news/

Usage:
    python manage.py import_mae_news              # import all
    python manage.py import_mae_news --dry-run    # preview only
"""

import io
import urllib.request
from datetime import datetime

from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import Article, Category


# All articles sourced from mae.gov.bi, ordered by date
ARTICLES = [
    {
        "title": "Burundi Celebrates Africa Day 2026",
        "date": "2026-05-25",
        "category": "Be 4 Africa",
        "content": (
            "Burundi commemorated Africa Day on May 25, 2026, under the leadership of President "
            "Évariste Ndayishimiye, who currently chairs the African Union. The celebration focused "
            "on the theme: \"Ensuring sustainable access to water and safe sanitation systems to "
            "achieve Agenda 2063 goals.\"\n\n"
            "The event featured exhibition stands showcasing products from African Union member nations. "
            "Minister of Foreign Affairs Ambassador Édouard Bizimana highlighted Burundi's 63 years of "
            "\"unity, integration, and development.\" He emphasized that the roundtable discussion served "
            "as \"an intellectual and civic space to promote open discussion among various actors\" including "
            "diplomats, academics, and youth.\n\n"
            "Key discussion topics included African diplomatic leadership, regional peace, education "
            "transformation, and youth employment. Minister Bizimana referenced Burundi's Youth Economic "
            "Empowerment and Employment Program and noted the country's contributions to UN and African "
            "Union peacekeeping operations.\n\n"
            "President Ndayishimiye called upon African youth to commit to \"peace, knowledge, innovation, "
            "environmental protection, and sustainable development.\" The celebration concluded with a "
            "football match between the Foreign Affairs Ministry team and the African Diplomatic Corps."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/05/afr-day-1-scaled.jpeg",
    },
    {
        "title": "Bujumbura Hosts the 61st UNSAC Meeting",
        "date": "2026-05-26",
        "category": "Governance",
        "content": (
            "From May 25-29, 2026, Bujumbura hosted the 61st Meeting of the United Nations Permanent "
            "Advisory Committee on Security Issues in Central Africa (UNSAC). The gathering focused on "
            "\"Strengthening regional mechanisms for the prevention, mediation and peaceful settlement "
            "of conflicts.\"\n\n"
            "Expert sessions began May 26, culminating in a ministerial meeting on May 29. Permanent "
            "Secretary Sophonie Nitunga welcomed representatives from all eleven Economic Community of "
            "Central African States (ECCAS) member nations, emphasizing that expert analyses would "
            "inform higher-level decision-making.\n\n"
            "Following presentations and elections, the Republic of Burundi was selected as Committee "
            "Chair, with Gabon as First Vice-Chair and the Democratic Republic of Congo as Second "
            "Vice-Chair."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/06/ph-unoca1-scaled.jpeg",
    },
    {
        "title": "UNSAC: Burundi Elected to the Presidency",
        "date": "2026-05-29",
        "category": "Governance",
        "content": (
            "The 61st United Nations Standing Advisory Committee on Security Questions in Central Africa "
            "concluded on May 29, 2026 in Bujumbura. During the ministerial meeting, Burundi was elected "
            "to lead the organization, with Gabon as First Vice-President, the Democratic Republic of Congo "
            "as Second Vice-President, and the Republic of Congo assuming secretarial duties.\n\n"
            "Foreign Minister Édouard Bizimana emphasized that regional challenges including climate change "
            "and humanitarian crises require unified responses. He stated: \"No single state can provide "
            "lasting solutions to the challenges facing the region.\"\n\n"
            "The ministers adopted two declarations: one addressing internal displacement prevention and "
            "protection of displaced persons, and another on strengthening conflict prevention mechanisms "
            "and peaceful resolution strategies throughout Central Africa."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/06/ph-discours-unoca-min-300x262.jpeg",
    },
    {
        "title": "Burundi Strengthens Partnerships for an Exemplary African Union Presidency",
        "date": "2026-06-01",
        "category": "Diplomacy",
        "content": (
            "Burundi's Foreign Minister Ambassador Édouard Bizimana met with major development partners "
            "including UN, EU, World Bank, and African Development Bank representatives on June 1, 2026.\n\n"
            "The minister outlined four priority initiatives for Burundi's AU presidency:\n"
            "• Continental Youth Dialogue on Peace and Security\n"
            "• Women and girls empowerment\n"
            "• Water, sanitation, and living conditions improvements\n"
            "• Education access for refugee children\n\n"
            "Partners pledged support and agreed to schedule technical meetings to develop concrete action "
            "plans. Notably, the AfDB approved $13 million to assist refugees in Burundi.\n\n"
            "The delegation members included Violet Kakyomya (UN Resident Coordinator), Elisabetta Pietrobon "
            "(EU Ambassador), Dr. Amadou Nchare (AfDB Country Representative), and Sayed Ghulam (World Bank "
            "Senior Health Specialist).\n\n"
            "The statement emphasized the collective goal: making \"Burundi's presidency of the African Union "
            "a continental example, marked by tangible progress in peace, security, and development.\""
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/06/ph-union-eur-scaled.jpeg",
    },
    {
        "title": "Burundi and FAO Strengthen Their Partnership Through Agricultural Projects",
        "date": "2026-06-01",
        "category": "Economy",
        "content": (
            "On June 1, 2026, Burundi's Ministry of Foreign Affairs hosted a working meeting to coordinate "
            "preparations for FAO field missions monitoring supported agricultural projects.\n\n"
            "The meeting focused on strengthening the partnership between Burundi and the Food and Agriculture "
            "Organization of the United Nations (FAO) through monitoring and evaluation of ongoing agricultural "
            "initiatives across the country.\n\n"
            "This collaboration reflects Burundi's commitment to food security and sustainable agricultural "
            "development as key pillars of its national development strategy."
        ),
        "image_url": "",
    },
    {
        "title": "Burundi and DRC: A Meeting to Strengthen Regional Cooperation",
        "date": "2026-06-01",
        "category": "Diplomacy",
        "content": (
            "On June 1, 2026, the Foreign Ministers of Burundi and the Democratic Republic of Congo held "
            "a bilateral meeting to discuss strengthening regional cooperation between the two nations.\n\n"
            "The meeting focused on shared interests in peace, security, and economic development in the "
            "Great Lakes region, reflecting both countries' commitment to deepening their diplomatic ties "
            "and working together on issues of mutual concern."
        ),
        "image_url": "",
    },
    {
        "title": "Minister Édouard Bizimana Receives US Chargé d'Affaires for Farewell Audience",
        "date": "2026-06-02",
        "category": "Diplomacy",
        "content": (
            "His Excellency Ambassador Édouard Bizimana, Minister of Foreign Affairs, Regional Integration "
            "and Development Cooperation, received Mrs. Amy Davison, Chargé d'Affaires at the Embassy of "
            "the United States of America in Burundi, in audience on June 2, 2026.\n\n"
            "This visit marked Mrs. Davison's departure from her diplomatic post in Burundi, providing an "
            "opportunity to review the state of bilateral relations and discuss future cooperation prospects "
            "between the two nations."
        ),
        "image_url": "",
    },
    {
        "title": "Minister Bizimana Receives British Delegation to Strengthen UK-Burundi Partnership",
        "date": "2026-06-02",
        "category": "Diplomacy",
        "content": (
            "On June 2, 2026, Foreign Minister Édouard Bizimana received a delegation from the British "
            "Embassy including development officials.\n\n"
            "The meeting focused on strengthening bilateral partnerships between Burundi and the United "
            "Kingdom, exploring areas of cooperation in development, trade, and diplomatic engagement."
        ),
        "image_url": "",
    },
    {
        "title": "Ministers from Burundi and DRC Visit ICGLR to Strengthen Peace and Regional Integration",
        "date": "2026-06-02",
        "category": "Diplomacy",
        "content": (
            "On June 2, 2026, ministers from Burundi and the Democratic Republic of Congo conducted a joint "
            "working visit to the International Conference on the Great Lakes Region (ICGLR) Secretariat "
            "in Bujumbura.\n\n"
            "The visit aimed to strengthen peace, security, and regional integration efforts in the Great "
            "Lakes region, underscoring both nations' commitment to collaborative approaches in addressing "
            "shared challenges."
        ),
        "image_url": "",
    },
    {
        "title": "Workshop on the Role of Women in Burundi's Development",
        "date": "2026-06-02",
        "category": "Culture",
        "content": (
            "On June 2, 2026, the Gender Unit of the Ministry of Foreign Affairs organized an awareness "
            "workshop for young ministry employees.\n\n"
            "The workshop connected women's contributions to Burundi's ambitious goals of achieving emergence "
            "by 2040 and sustainable development by 2060. It highlighted the critical role of women in "
            "national development and the importance of gender-inclusive policies across all sectors."
        ),
        "image_url": "",
    },
    {
        "title": "Launch of the National Consultative Meeting on COP31 in Burundi",
        "date": "2026-06-03",
        "category": "Governance",
        "content": (
            "On June 3, 2026, Director-General Aimé Nkurunziza launched national consultative meetings on "
            "Burundi's climate strategy in preparation for COP31.\n\n"
            "The consultative meetings brought together stakeholders across EAC partner states to develop "
            "coordinated positions on climate action, sustainable development, and environmental protection "
            "ahead of the upcoming UN Climate Change Conference."
        ),
        "image_url": "",
    },
    {
        "title": "Minister Bizimana Bids Farewell to German Ambassador",
        "date": "2026-06-06",
        "category": "Diplomacy",
        "content": (
            "On June 6, 2026, Foreign Minister Édouard Bizimana received Ambassador Carsten Holscher "
            "of Germany for a farewell audience marking the conclusion of his diplomatic posting in Burundi.\n\n"
            "The meeting provided an opportunity to review the state of German-Burundian cooperation and "
            "discuss prospects for continued bilateral engagement. Ambassador Holscher's departure marks "
            "the end of a productive diplomatic tenure focused on development cooperation between the "
            "two nations."
        ),
        "image_url": "",
    },
    {
        "title": "Minister Bizimana Meets with IMF Resident Representative",
        "date": "2026-06-06",
        "category": "Economy",
        "content": (
            "On June 6, 2026, Foreign Minister Édouard Bizimana met with IMF Resident Representative "
            "Samuel Delepierre, who concluded his three-and-a-half-year mission in Burundi.\n\n"
            "The meeting featured exchanges of gratitude for the constructive cooperation between Burundi "
            "and the International Monetary Fund during Mr. Delepierre's tenure. Discussions touched on "
            "Burundi's economic outlook and the continued importance of sound macroeconomic policies for "
            "the country's development ambitions."
        ),
        "image_url": "",
    },
    {
        "title": "Roundtable on Burundi's Presidency of the African Union",
        "date": "2026-06-09",
        "category": "Be 4 Africa",
        "content": (
            "On June 9, 2026, the Republic of Burundi marked a major diplomatic milestone by opening the "
            "proceedings of the Roundtable dedicated to its Presidency of the African Union.\n\n"
            "The event, led by Foreign Minister Ambassador Edouard Bizimana, brought together government "
            "officials, the diplomatic corps, international technical and financial partners, the private "
            "sector, civil society, universities, research centers, young people, and the media.\n\n"
            "The Burundian presidency focuses on four main areas:\n"
            "• Water sustainability and climate resilience\n"
            "• Regional security and conflict prevention\n"
            "• Inclusive education and youth empowerment\n"
            "• Women's economic and political participation\n\n"
            "Minister Bizimana described the AU presidency as \"a mark of confidence from the Member States,\" "
            "representing Burundi's return to the international stage after years of isolation. The presidency "
            "offers opportunities for representing Africa in forums like the G20 and United Nations.\n\n"
            "Success depends on uniting AU member states, regional and international organizations, civil "
            "society, and the private sector."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/06/PH-TABL1-300x202.jpeg",
    },
    {
        "title": "US Chargé d'Affaires Bridget Premont Received in Audience",
        "date": "2026-06-12",
        "category": "Diplomacy",
        "content": (
            "On June 12, 2026, Burundi's Foreign Minister Ambassador Edouard Bizimana met with Mrs. Bridget "
            "Premont, the interim U.S. Embassy representative, for a courtesy visit discussing mutual interests.\n\n"
            "Minister Bizimana welcomed the meeting and emphasized \"excellent relations of friendship and "
            "cooperation between Burundi and the United States.\" He noted that some bilateral initiatives "
            "had stalled following the previous official's departure but expressed optimism about reviving them.\n\n"
            "Premont committed to \"working energetically and in close collaboration on the ongoing projects\" "
            "and proposed scheduling technical meetings to expedite implementation.\n\n"
            "The U.S. has provided approximately $4 million to Burundi in response to emergency humanitarian "
            "needs related to Ebola. Premont confirmed Washington's continued commitment to supporting "
            "Burundi in peace, security, and development cooperation.\n\n"
            "Regarding visa processing for Burundian citizens, Premont indicated the embassy would provide "
            "official clarification through diplomatic channels."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/06/ph-aud-EU.jpg",
    },
    {
        "title": "Burundi and Turkey Strengthen Their Cooperation in Various Fields",
        "date": "2026-06-17",
        "category": "Diplomacy",
        "content": (
            "The Joint Economic Commission between Burundi and Turkey held its inaugural session in Ankara "
            "on June 16-17, 2026. Burundi's delegation was headed by Foreign Minister Edouard Bizimana, "
            "while Turkey's was led by Defense Minister Yasar Güler.\n\n"
            "This was Minister Bizimana's first official visit to Turkey. Turkish officials congratulated "
            "Burundi on assuming African Union leadership.\n\n"
            "Both nations emphasized expanding collaboration across multiple sectors: trade, investment, "
            "tourism, agriculture, education, transport, health, and communication. Delegates stressed "
            "the importance of diversifying cooperation through mutual benefit.\n\n"
            "Minister Bizimana visited Turkish companies and symbolically planted a tree to represent "
            "nurturing bilateral relations. The discussions reflected mutual commitment to strengthening "
            "friendly ties and economic partnerships."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/07/ph-turquie.png",
    },
    {
        "title": "Burundi Peacebuilding Week: A Lever of Hope for the Community",
        "date": "2026-06-22",
        "category": "Governance",
        "content": (
            "On June 22, 2026, Foreign Minister Édouard Bizimana launched Burundi's inaugural Peacebuilding "
            "Week at the Donatus Conference Center. The event, themed \"United Nations peacebuilding at the "
            "dawn of the 20th anniversary: Partnerships for innovation, inclusion and impact,\" ran through "
            "June 25 and coincided with the 20th anniversary of the UN Peacebuilding Fund.\n\n"
            "The Minister acknowledged the First Lady's patronage and praised support from the Peacebuilding "
            "Commission, Peacebuilding Support Office, and contributing nations. He noted that Burundi was "
            "among the first countries establishing a strategic partnership with the PBF, transitioning from "
            "crisis through \"reconstruction and dialogue.\"\n\n"
            "Key accomplishments highlighted include strengthening inclusive security forces, advancing rule "
            "of law reforms, peacefully reintegrating hundreds of thousands of returnees and displaced persons, "
            "and establishing local dispute resolution mechanisms.\n\n"
            "Bizimana emphasized youth and women's central roles in national peacebuilding architecture, "
            "aligning with UN Security Council Resolutions 2250 and 1325. He called on the diplomatic corps, "
            "private sector, and civil society to intensify partnerships and leverage digital technologies "
            "for innovation.\n\n"
            "The ceremony featured traditional drums symbolizing peace and unity."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/06/ph-cons-de-la-paix-min-291x300.jpeg",
    },
    {
        "title": "Annual Retreat for Burundi's Heads of Diplomatic and Consular Missions",
        "date": "2026-06-23",
        "category": "Diplomacy",
        "content": (
            "On June 23, 2026, Burundi's Ministry of Foreign Affairs organized its annual retreat for "
            "diplomatic and consular heads under the theme \"Towards a Burundian diplomacy adapted to "
            "global and regional challenges.\"\n\n"
            "Minister Édouard Bizimana highlighted the significance of this edition, noting that it takes "
            "place while Burundi holds the African Union presidency amid rapid international shifts including "
            "political instability, economic turbulence, security threats, pandemics, and digital transformation.\n\n"
            "The minister emphasized that \"Burundian diplomacy\" must evolve beyond traditional representation "
            "into proactive, innovative approaches focused on national interests. The government aims to develop "
            "a diplomatic corps capable of anticipating global changes, capitalizing on opportunities through "
            "globalization, defending national positions regionally and internationally, and integrating digital "
            "innovations into strategy."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/06/ph-retraite-min-1-300x207.jpeg",
    },
    {
        "title": "Diplomatic Week 2026: Economy at the Heart of Burundian Diplomacy",
        "date": "2026-06-26",
        "category": "Economy",
        "content": (
            "On June 26, 2026, Ambassador Édouard Bizimana, the Foreign Affairs Minister, inaugurated the "
            "11th Diplomatic Week in Bujumbura, emphasizing economic engagement as central to national "
            "strategy. The event's theme focused on \"Economic Diplomacy and Strategic Partnerships\" "
            "supporting Burundi's Vision 2040-2060.\n\n"
            "The minister outlined five strategic pillars:\n"
            "• Foreign investment attraction\n"
            "• Technology transfer\n"
            "• Tourism advancement\n"
            "• Industrial expansion\n"
            "• Infrastructure projects\n\n"
            "Minister Bizimana stated: \"Economic diplomacy and strategic partnerships serve as essential "
            "pillars to propel Burundi toward emergence by 2040 and sustainable development by 2060.\"\n\n"
            "Participants toured the Afritextile Company to observe investment impacts and business "
            "opportunities firsthand."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/06/ph-ouv-sd-2-scaled.jpeg",
    },
    {
        "title": "Minister Bizimana Meets with Sudan's Ambassador",
        "date": "2026-06-29",
        "category": "Diplomacy",
        "content": (
            "On June 29, 2026, Burundi's Minister of Foreign Affairs, Ambassador Edouard Bizimana, met "
            "with Sudan's Ambassador Ahmed Ibrahim Ahmed Awadelseed for a farewell audience as the "
            "ambassador concluded his posting.\n\n"
            "The Sudanese ambassador expressed gratitude for \"the warm welcome he had received during his "
            "mission,\" praising collaboration with Burundian officials as \"constructive and exemplary.\" "
            "Discussions centered on strengthening bilateral relations between the two nations.\n\n"
            "The ambassador commended Burundi's African Union presidency and its \"Diplomatic Week\" initiative, "
            "calling it valuable for fostering diplomatic exchanges. He requested Burundi's support in restoring "
            "security in Khartoum, referencing commitments from the September 2025 ICGLR Summit in Kinshasa.\n\n"
            "Minister Bizimana affirmed Burundi's commitment to supporting Sudan's peace efforts, noting that "
            "Sudan's humanitarian and security situation features prominently in Burundi's AU agenda. He "
            "emphasized his nation's dedication to expanding \"mechanisms for restoring peace in the Sahel region.\""
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/07/ph-amb-sudan1-291x300.jpeg",
    },
    {
        "title": "Bugarama: Reflections on Burundi's Progress and Its Many Opportunities",
        "date": "2026-06-30",
        "category": "Economy",
        "content": (
            "The 11th edition of the Diplomatic Week concluded in Bugarama on June 30, 2026, with a closing "
            "ceremony presided over by Ambassador Édouard Bizimana, Minister of Foreign Affairs, Regional "
            "Integration and Development Cooperation.\n\n"
            "The Minister expressed gratitude to all participants, emphasizing that \"this week offered "
            "diplomats a privileged opportunity to discover the progress made by Burundi.\" He highlighted "
            "the nation's natural beauty, its people's strength, and available investment prospects.\n\n"
            "The gathering brought together heads of diplomatic missions both accredited to Burundi and "
            "stationed abroad, fostering \"exchange of experiences and promoting economic diplomacy.\" "
            "Officials observed firsthand that \"peace, security, and stability are a reality in Burundi, "
            "essential conditions for attracting investment.\"\n\n"
            "In closing, the Minister reaffirmed government commitment to implementing the \"National Vision "
            "'Burundi, an emerging country by 2040 and a developed country by 2060,'\" which served as the "
            "event's central theme."
        ),
        "image_url": "https://www.mae.gov.bi/en/wp-content/uploads/2026/07/SD-CLOTURE-2.jpeg",
    },
    {
        "title": "Diplomatic Visits Highlight Government Interest in Burundi's Private Sector",
        "date": "2026-07-10",
        "category": "Economy",
        "content": (
            "Following the Diplomatic Week 2026 Edition (June 26-30, 2026), the diplomatic corps toured "
            "several Burundian enterprises and attractions under the theme \"Economic Diplomacy and "
            "Strategic Partnerships.\"\n\n"
            "Facilities visited included:\n"
            "• Afritextile (Bujumbura): Manufacture and sale of Kitenge fabrics, polyester-cotton products "
            "with three main workshops in spinning, weaving, and dyeing/printing.\n"
            "• Tora Tea Complex (Matana): A processing unit under the Burundi Tea Board.\n"
            "• Source of the Nile (Matana): The southernmost White Nile source, discovered by explorer "
            "Burkhart Waldecker.\n"
            "• Karera Falls: A spectacular 45-meter waterfall with suspension bridge views.\n"
            "• CEFORE-RUSI (Gitega): Training center that has trained more than 1,000 learners.\n"
            "• Umugiraneza Foundation (Kibimba): Humanitarian organization providing education and "
            "specialized care.\n\n"
            "Minister Édouard Bizimana emphasized that \"diplomacy constitutes a powerful tool for tourism "
            "promotion\" and tourism development aligns with Burundi's vision of becoming \"an emerging "
            "country by 2040 and a developed country by 2060.\""
        ),
        "image_url": "",
    },
]

AUTHOR = 'Burundi'

CATEGORY_FR_MAP = {
    'Diplomacy': 'Diplomatie',
    'Governance': 'Gouvernance',
    'Health': 'Santé',
    'Economy': 'Économie',
    'Be 4 Africa': "Présidence de l'UA",
    'Culture': 'Culture',
}
CATEGORY_COLORS = {
    'Diplomacy': '#1EB53A',
    'Governance': '#CE1126',
    'Health': '#0077B6',
    'Economy': '#F4A261',
    'Be 4 Africa': '#FFD700',
    'Culture': '#9B59B6',
}


class Command(BaseCommand):
    help = 'Import MAE website news articles (May 21 – Jul 10, 2026) into Articles'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run', action='store_true',
            help='Preview what would be imported without saving',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN — nothing will be saved\n'))

        created = 0
        skipped = 0
        errors = 0

        for entry in ARTICLES:
            title = entry['title']

            # Skip duplicates
            if Article.objects.filter(title=title).exists():
                self.stdout.write(f'  SKIP (exists): {title}')
                skipped += 1
                continue

            if dry_run:
                self.stdout.write(f'  WOULD CREATE: [{entry["category"]}] {title} ({entry["date"]})')
                created += 1
                continue

            try:
                # Parse date
                pub_date = timezone.make_aware(
                    datetime.strptime(entry['date'], '%Y-%m-%d')
                )

                # Get or create category
                cat_name = entry['category']
                category, _ = Category.objects.get_or_create(
                    name=cat_name,
                    defaults={
                        'name_fr': CATEGORY_FR_MAP.get(cat_name, cat_name),
                        'color': CATEGORY_COLORS.get(cat_name, '#1EB53A'),
                    },
                )

                article = Article(
                    title=title,
                    content=entry['content'],
                    author=AUTHOR,
                    category=category,
                    publish_date=pub_date,
                    content_type='news',
                    status='published',
                    is_featured=False,
                )

                # Download and attach image if available
                image_url = entry.get('image_url', '')
                if image_url:
                    try:
                        req = urllib.request.Request(
                            image_url,
                            headers={'User-Agent': 'Mozilla/5.0'},
                        )
                        with urllib.request.urlopen(req, timeout=15) as resp:
                            img_data = resp.read()
                        ext = image_url.rsplit('.', 1)[-1].split('?')[0][:5]
                        fname = f'mae_news_{entry["date"]}_{created}.{ext}'
                        article.image.save(fname, ContentFile(img_data), save=False)
                        self.stdout.write(f'    Image downloaded: {fname}')
                    except Exception as img_err:
                        self.stdout.write(self.style.WARNING(
                            f'    Image download failed: {img_err}'
                        ))

                article.save()
                created += 1
                self.stdout.write(self.style.SUCCESS(
                    f'  CREATED: [{cat_name}] {title} ({entry["date"]})'
                ))

            except Exception as e:
                errors += 1
                self.stdout.write(self.style.ERROR(f'  ERROR: {title}: {e}'))

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(
            f'Done! Created: {created}, Skipped: {skipped}, Errors: {errors}'
        ))
