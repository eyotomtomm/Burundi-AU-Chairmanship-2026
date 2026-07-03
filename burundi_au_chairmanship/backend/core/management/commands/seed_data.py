from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone
from core.models import (
    Article, MagazineEdition, EmbassyLocation, Event,
    LiveFeed, Resource, AppSettings,
    FeatureCard, HeroSlide, PriorityAgenda, GalleryAlbum,
    GalleryPhoto, Video, SocialMediaLink, Category,
    QuickAccessMenuItem, WeatherCity, HeroTextContent, Notification,
    FeatureCardKeyPoint, FeatureCardImpactArea,
    EventRegistration, RegistrationFormField,
    EmergencyContact,
)


class Command(BaseCommand):
    help = 'Seed the database with initial data'

    def handle(self, *args, **options):
        self.stdout.write('Seeding data...')

        # Admin user
        if not User.objects.filter(is_superuser=True).exists():
            import os
            from django.conf import settings as django_settings
            admin_password = os.environ.get('DJANGO_ADMIN_PASSWORD')
            if admin_password:
                User.objects.create_superuser('admin', 'admin@burundi.gov.bi', admin_password)
                self.stdout.write('  Admin user created with password from DJANGO_ADMIN_PASSWORD')
            elif not django_settings.DEBUG:
                raise CommandError(
                    'Refusing to create admin user in production without DJANGO_ADMIN_PASSWORD. '
                    'Set the DJANGO_ADMIN_PASSWORD environment variable and re-run.'
                )
            else:
                import secrets
                admin_password = secrets.token_urlsafe(16)
                User.objects.create_superuser('admin', 'admin@burundi.gov.bi', admin_password)
                self.stdout.write(self.style.WARNING(
                    f'  Admin user created with random password: {admin_password}'
                ))
                self.stdout.write(self.style.WARNING(
                    '  Set DJANGO_ADMIN_PASSWORD env var to use a fixed password.'
                ))

        # App Settings
        AppSettings.objects.get_or_create(
            summit_year='2026',
            defaults={
                'summit_theme': 'Africa We Want: Building a Resilient and Prosperous Continent',
                'summit_theme_fr': "L'Afrique que nous voulons: Construire un continent résilient et prospère",
                'website_url': 'https://www.burundi.gov.bi',
                'facebook_url': 'https://facebook.com/BurundiGov',
                'twitter_url': 'https://twitter.com/BurundiGov',
                'instagram_url': 'https://instagram.com/BurundiGov',
            }
        )
        self.stdout.write('  App Settings created')

        # Hero Slides
        hero_slides = [
            {'label': 'Be 4 Africa 2026', 'label_fr': 'Présidence UA du Burundi 2026', 'order': 1},
            {'label': 'Building a Resilient Africa', 'label_fr': 'Construire une Afrique résiliente', 'order': 2},
            {'label': 'Unity in Diversity', 'label_fr': 'Unité dans la diversité', 'order': 3},
            {'label': 'A Prosperous Continent', 'label_fr': 'Un continent prospère', 'order': 4},
        ]
        for slide in hero_slides:
            HeroSlide.objects.get_or_create(label=slide['label'], defaults=slide)
        self.stdout.write(f'  {len(hero_slides)} Hero Slides created')

        # Hero Text Content
        hero_texts = [
            {'key': 'badge', 'text_en': 'BURUNDI', 'text_fr': 'BURUNDI'},
            {'key': 'title_line1', 'text_en': 'African Union', 'text_fr': 'Union Africaine'},
            {'key': 'title_line2', 'text_en': 'Chairmanship', 'text_fr': 'Présidence'},
            {'key': 'year', 'text_en': '2026', 'text_fr': '2026'},
        ]
        for hero_text in hero_texts:
            HeroTextContent.objects.get_or_create(key=hero_text['key'], defaults=hero_text)
        self.stdout.write(f'  {len(hero_texts)} Hero Text Content items created')

        # Feature Cards
        feature_cards = [
            {
                'title': 'AU Summit 2026',
                'title_fr': 'Sommet UA 2026',
                'description': 'Follow the African Union Summit live with updates and coverage.',
                'description_fr': "Suivez le Sommet de l'Union Africaine en direct avec des mises à jour et une couverture.",
                'gradient_start': '#1EB53A',
                'gradient_end': '#4CAF50',
                'icon_name': 'stars',
                'action_type': 'route',
                'action_value': '/feature-detail',
                'order': 1,
                'overview': 'The 2026 African Union Summit marks a historic milestone as Burundi assumes the chairmanship of the continental body. Under the theme "Africa We Want: Building a Resilient and Prosperous Continent," leaders from all 55 member states will convene to address the most pressing challenges and opportunities facing the continent.\n\nThis summit will focus on accelerating the implementation of Agenda 2063, strengthening continental integration, and positioning Africa as a global leader in sustainable development.',
                'overview_fr': "Le Sommet de l'Union Africaine 2026 marque un jalon historique alors que le Burundi assume la présidence de l'organe continental. Sous le thème « L'Afrique que nous voulons : Construire un continent résilient et prospère », les dirigeants des 55 États membres se réuniront pour aborder les défis et opportunités les plus urgents du continent.\n\nCe sommet se concentrera sur l'accélération de la mise en œuvre de l'Agenda 2063, le renforcement de l'intégration continentale et le positionnement de l'Afrique en tant que leader mondial du développement durable.",
                'key_points': [
                    'Accelerating the implementation of Agenda 2063 — The Africa We Want',
                    'Strengthening continental free trade under the AfCFTA framework',
                    'Advancing the Silencing the Guns initiative for lasting peace',
                    'Promoting youth empowerment and digital transformation across Africa',
                    'Enhancing climate resilience and sustainable development strategies',
                    'Fostering Pan-African unity and solidarity among member states',
                ],
                'key_points_fr': [
                    "Accélérer la mise en œuvre de l'Agenda 2063 — L'Afrique que nous voulons",
                    "Renforcer le libre-échange continental dans le cadre de la ZLECAf",
                    "Faire avancer l'initiative Faire taire les armes pour une paix durable",
                    "Promouvoir l'autonomisation des jeunes et la transformation numérique",
                    "Renforcer la résilience climatique et les stratégies de développement durable",
                    "Favoriser l'unité et la solidarité panafricaines entre les États membres",
                ],
                'impact_areas': [
                    {'icon': 'public', 'title': 'Continental Integration', 'description': 'Deepening economic and political integration across all 55 member states through trade, infrastructure, and shared governance.'},
                    {'icon': 'security', 'title': 'Peace & Security', 'description': 'Advancing conflict prevention, peacekeeping operations, and the Silencing the Guns agenda across the continent.'},
                    {'icon': 'trending_up', 'title': 'Economic Growth', 'description': 'Implementing the AfCFTA to create the world\'s largest free trade area and boost intra-African trade.'},
                    {'icon': 'groups', 'title': 'Youth & Innovation', 'description': 'Empowering Africa\'s young population through education, technology, and entrepreneurship programs.'},
                ],
                'impact_areas_fr': [
                    {'icon': 'public', 'title': 'Intégration continentale', 'description': "Approfondir l'intégration économique et politique à travers les 55 États membres."},
                    {'icon': 'security', 'title': 'Paix et sécurité', 'description': "Avancer la prévention des conflits et l'agenda Faire taire les armes."},
                    {'icon': 'trending_up', 'title': 'Croissance économique', 'description': "Mise en œuvre de la ZLECAf pour créer la plus grande zone de libre-échange au monde."},
                    {'icon': 'groups', 'title': 'Jeunesse et innovation', 'description': "Autonomiser la jeunesse africaine par l'éducation, la technologie et l'entrepreneuriat."},
                ],
                'extra_content': 'The Bujumbura Convention Center will serve as the main venue for the summit, hosting plenary sessions, bilateral meetings, and cultural exhibitions. Delegates and visitors will also have the opportunity to experience Burundi\'s rich cultural heritage, including performances by the legendary Karyenda drummers — a UNESCO Intangible Cultural Heritage.',
                'extra_content_fr': "Le Centre de Conventions de Bujumbura servira de lieu principal pour le sommet, accueillant des sessions plénières, des réunions bilatérales et des expositions culturelles. Les délégués et visiteurs auront également l'occasion de découvrir le riche patrimoine culturel du Burundi, y compris les performances des légendaires tambourinaires du Karyenda — patrimoine culturel immatériel de l'UNESCO.",
            },
            {
                'title': 'Discover Burundi',
                'title_fr': 'Découvrir le Burundi',
                'description': "Explore Burundi's rich culture, history, and natural beauty.",
                'description_fr': "Explorez la riche culture, l'histoire et la beauté naturelle du Burundi.",
                'gradient_start': '#CE1126',
                'gradient_end': '#E57373',
                'icon_name': 'travel_explore',
                'action_type': 'route',
                'action_value': '/feature-detail',
                'order': 2,
                'overview': "Burundi, known as the \"Heart of Africa,\" is a land of breathtaking landscapes, vibrant culture, and warm hospitality. Nestled in the Great Rift Valley, the country boasts stunning natural wonders including Lake Tanganyika — the world's second-deepest lake — lush mountain ranges, and diverse wildlife.\n\nFrom the rhythmic beats of the Karyenda drums to the rolling hills covered in tea and coffee plantations, Burundi offers a unique African experience that captivates every visitor.",
                'overview_fr': "Le Burundi, connu comme le « Cœur de l'Afrique », est une terre de paysages à couper le souffle, de culture vibrante et d'hospitalité chaleureuse. Niché dans la vallée du Grand Rift, le pays possède des merveilles naturelles époustouflantes, dont le lac Tanganyika — le deuxième lac le plus profond du monde — des chaînes de montagnes luxuriantes et une faune diversifiée.\n\nDes battements rythmiques des tambours du Karyenda aux collines couvertes de plantations de thé et de café, le Burundi offre une expérience africaine unique qui captive chaque visiteur.",
                'key_points': [
                    'Home to Lake Tanganyika — the longest freshwater lake in the world and second deepest',
                    'UNESCO-recognized Ritual Dance of the Royal Drum (Karyenda) — a living cultural treasure',
                    'Source of the southernmost headwaters of the Nile River',
                    'Rich biodiversity with Kibira National Park and Rusizi Nature Reserve',
                    'Thriving coffee and tea culture — Burundian coffee is among Africa\'s finest',
                    'A young, dynamic population driving innovation and entrepreneurship',
                ],
                'key_points_fr': [
                    "Abrite le lac Tanganyika — le lac d'eau douce le plus long du monde et le deuxième plus profond",
                    "Danse rituelle du tambour royal (Karyenda) reconnue par l'UNESCO — un trésor culturel vivant",
                    "Source des eaux les plus méridionales du Nil",
                    "Riche biodiversité avec le Parc National de la Kibira et la Réserve Naturelle de la Rusizi",
                    "Culture florissante du café et du thé — le café burundais est parmi les meilleurs d'Afrique",
                    "Une population jeune et dynamique qui stimule l'innovation et l'entrepreneuriat",
                ],
                'impact_areas': [
                    {'icon': 'landscape', 'title': 'Natural Wonders', 'description': 'Lake Tanganyika, Kibira National Park, Karera Waterfalls, and the source of the Nile offer unforgettable experiences.'},
                    {'icon': 'music_note', 'title': 'Cultural Heritage', 'description': 'The legendary Karyenda drummers, Intore dancers, and rich oral traditions reflect centuries of cultural wealth.'},
                    {'icon': 'restaurant', 'title': 'Cuisine & Coffee', 'description': 'World-class single-origin coffee, traditional dishes, and a thriving culinary scene showcase Burundian flavors.'},
                    {'icon': 'diversity_3', 'title': 'People & Hospitality', 'description': 'Known for warmth and generosity, Burundians welcome visitors with open arms and genuine friendliness.'},
                ],
                'impact_areas_fr': [
                    {'icon': 'landscape', 'title': 'Merveilles naturelles', 'description': "Le lac Tanganyika, le Parc National de la Kibira et les chutes de Karera offrent des expériences inoubliables."},
                    {'icon': 'music_note', 'title': 'Patrimoine culturel', 'description': "Les tambourinaires du Karyenda, les danseurs Intore et les riches traditions orales."},
                    {'icon': 'restaurant', 'title': 'Cuisine et café', 'description': "Café d'origine unique de classe mondiale et une scène culinaire florissante."},
                    {'icon': 'diversity_3', 'title': 'Peuple et hospitalité', 'description': "Connus pour leur chaleur et leur générosité, les Burundais accueillent les visiteurs à bras ouverts."},
                ],
                'extra_content': "Whether you're exploring the bustling markets of Bujumbura, trekking through the misty forests of Kibira, or watching the sun set over Lake Tanganyika, Burundi promises an authentic and enriching journey. The country is rapidly developing its tourism infrastructure while preserving its natural beauty and cultural authenticity.",
                'extra_content_fr': "Que vous exploriez les marchés animés de Bujumbura, que vous fassiez de la randonnée dans les forêts brumeuses de la Kibira ou que vous regardiez le soleil se coucher sur le lac Tanganyika, le Burundi promet un voyage authentique et enrichissant. Le pays développe rapidement ses infrastructures touristiques tout en préservant sa beauté naturelle et son authenticité culturelle.",
            },
        ]
        for fc in feature_cards:
            kp_en = fc.pop('key_points', [])
            kp_fr = fc.pop('key_points_fr', [])
            ia_en = fc.pop('impact_areas', [])
            ia_fr = fc.pop('impact_areas_fr', [])
            card, created = FeatureCard.objects.update_or_create(title=fc['title'], defaults=fc)
            # Rebuild child rows on every seed (idempotent)
            card.key_point_items.all().delete()
            for i, text in enumerate(kp_en):
                FeatureCardKeyPoint.objects.create(
                    feature_card=card,
                    text=str(text),
                    text_fr=str(kp_fr[i]) if i < len(kp_fr) else '',
                    order=i,
                )
            card.impact_area_items.all().delete()
            for i, area in enumerate(ia_en):
                if not isinstance(area, dict):
                    continue
                fr_area = ia_fr[i] if i < len(ia_fr) and isinstance(ia_fr[i], dict) else {}
                FeatureCardImpactArea.objects.create(
                    feature_card=card,
                    icon_name=area.get('icon', 'stars'),
                    title=area.get('title', ''),
                    title_fr=fr_area.get('title', ''),
                    description=area.get('description', ''),
                    description_fr=fr_area.get('description', ''),
                    order=i,
                )
        self.stdout.write(f'  {len(feature_cards)} Feature Cards created/updated (with key points & impact areas)')

        # ── Quick Access Menu ─────────────────────────────────────
        quick_access_items = [
            {
                'title_en': 'Live',
                'title_fr': 'En direct',
                'icon_name': 'play_circle_filled',
                'action_type': 'route',
                'action_value': '/live-feeds',
                'order': 1,
                'has_live_indicator': True,
                'auto_badge': True,
                'auto_badge_days': 3,
                'badge_text': '',
                'badge_color': '#E53935',
            },
            {
                'title_en': 'Magazine',
                'title_fr': 'Magazine',
                'icon_name': 'auto_stories',
                'action_type': 'route',
                'action_value': '/magazine',
                'order': 2,
                'auto_badge': True,
                'auto_badge_days': 7,
                'badge_text': '',
                'badge_color': '#E53935',
            },
            {
                'title_en': 'Resources',
                'title_fr': 'Ressources',
                'icon_name': 'folder_copy',
                'action_type': 'route',
                'action_value': '/resources',
                'order': 3,
                'auto_badge': True,
                'auto_badge_days': 3,
                'badge_text': '',
                'badge_color': '#E53935',
            },
            {
                'title_en': 'News',
                'title_fr': 'Actualités',
                'icon_name': 'article',
                'action_type': 'route',
                'action_value': '/news',
                'order': 4,
                'auto_badge': True,
                'auto_badge_days': 3,
                'badge_text': '',
                'badge_color': '#1E88E5',
            },
            {
                'title_en': 'Translate',
                'title_fr': 'Traduire',
                'icon_name': 'translate',
                'action_type': 'route',
                'action_value': '/translate',
                'order': 5,
                'auto_badge': False,
                'auto_badge_days': 3,
                'badge_text': '',
                'badge_color': '#E53935',
            },
            {
                'title_en': 'Weather',
                'title_fr': 'Météo',
                'icon_name': 'cloud',
                'action_type': 'route',
                'action_value': '/weather',
                'order': 6,
                'auto_badge': False,
                'auto_badge_days': 3,
                'badge_text': '',
                'badge_color': '#E53935',
            },
            {
                'title_en': 'Calendar',
                'title_fr': 'Calendrier',
                'icon_name': 'calendar_month',
                'action_type': 'route',
                'action_value': '/calendar',
                'order': 7,
                'auto_badge': True,
                'auto_badge_days': 3,
                'badge_text': '',
                'badge_color': '#E53935',
            },
        ]
        for qa in quick_access_items:
            QuickAccessMenuItem.objects.update_or_create(
                title_en=qa['title_en'], defaults=qa)
        self.stdout.write(f'  {len(quick_access_items)} Quick Access items created/updated')

        # ── Categories ────────────────────────────────────────────
        categories_data = [
            {'name': 'Politics', 'name_fr': 'Politique', 'color': '#1EB53A', 'order': 1},
            {'name': 'Economy', 'name_fr': 'Économie', 'color': '#D4AF37', 'order': 2},
            {'name': 'Culture', 'name_fr': 'Culture', 'color': '#CE1126', 'order': 3},
            {'name': 'Diplomacy', 'name_fr': 'Diplomatie', 'color': '#0A66C2', 'order': 4},
        ]
        category_map = {}
        for cat in categories_data:
            obj, _ = Category.objects.get_or_create(name=cat['name'], defaults=cat)
            category_map[cat['name'].lower()] = obj
        self.stdout.write(f'  {len(categories_data)} Categories created')

        # Magazine Editions (with external_url for PDF viewing)
        editions = [
            {
                'title': 'AU Summit Special Edition',
                'title_fr': "Édition spéciale du Sommet de l'UA",
                'description': "Complete coverage of the AU Summit by Be 4 Africa.",
                'description_fr': "Couverture complète du Sommet de l'UA et de la présidence du Burundi.",
                'publish_date': '2026-02-01',
                'is_featured': True,
                'external_url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
                'page_count': 48,
                'file_size': '12.4 MB',
            },
            {
                'title': 'Burundi: A Nation Rising',
                'title_fr': 'Burundi: Une nation en essor',
                'description': "Exploring Burundi's economic growth and development initiatives.",
                'description_fr': 'Explorer la croissance économique et les initiatives de développement du Burundi.',
                'publish_date': '2026-01-15',
                'is_featured': False,
                'external_url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
                'page_count': 32,
                'file_size': '8.2 MB',
            },
            {
                'title': 'African Unity in Action',
                'title_fr': "L'unité africaine en action",
                'description': 'How African nations are working together for continental progress.',
                'description_fr': 'Comment les nations africaines travaillent ensemble pour le progrès continental.',
                'publish_date': '2026-01-01',
                'is_featured': False,
                'external_url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
                'page_count': 24,
                'file_size': '6.1 MB',
            },
        ]
        for ed in editions:
            MagazineEdition.objects.get_or_create(title=ed['title'], defaults=ed)
        self.stdout.write(f'  {len(editions)} Magazine Editions created')

        # ── Articles (linked to Category FK) ─────────────────────
        articles = [
            {
                'title': 'Burundi Takes the Helm of African Union',
                'title_fr': "Le Burundi prend la tête de l'Union Africaine",
                'content': "In a historic moment, Burundi assumes the chairmanship of the African Union, marking a new chapter in the nation's diplomatic journey. President Ndayishimiye outlined an ambitious agenda focused on economic integration, peace and security, and youth empowerment across the continent.",
                'content_fr': "Dans un moment historique, le Burundi assume la présidence de l'Union Africaine, marquant un nouveau chapitre dans le parcours diplomatique de la nation. Le Président Ndayishimiye a présenté un agenda ambitieux axé sur l'intégration économique, la paix et la sécurité, et l'autonomisation des jeunes à travers le continent.",
                'author': 'AU Press Office',
                'category_key': 'politics',
                'publish_date': '2026-02-01T10:00:00Z',
                'is_featured': True,
            },
            {
                'title': 'Economic Development Initiatives for Africa',
                'title_fr': "Initiatives de développement économique pour l'Afrique",
                'content': 'New economic policies aim to boost trade and investment across the African continent, with a focus on digital transformation and sustainable agriculture.',
                'content_fr': "De nouvelles politiques économiques visent à stimuler le commerce et les investissements à travers le continent africain, avec un accent sur la transformation numérique et l'agriculture durable.",
                'author': 'Economic Desk',
                'category_key': 'economy',
                'publish_date': '2026-01-28T14:00:00Z',
                'is_featured': True,
            },
            {
                'title': 'Cultural Heritage Celebration at the Summit',
                'title_fr': 'Célébration du patrimoine culturel au Sommet',
                'content': "A grand celebration of Burundi's rich cultural heritage takes center stage at the summit, featuring the legendary Karyenda drummers and traditional dance performances.",
                'content_fr': "Une grande célébration du riche patrimoine culturel du Burundi occupe le devant de la scène lors du sommet, mettant en vedette les légendaires tambourinaires du Karyenda et des spectacles de danse traditionnelle.",
                'author': 'Culture Editor',
                'category_key': 'culture',
                'publish_date': '2026-01-20T09:00:00Z',
                'is_featured': False,
            },
            {
                'title': 'Diplomatic Relations Strengthened',
                'title_fr': 'Relations diplomatiques renforcées',
                'content': 'Multiple bilateral agreements signed during the summit, strengthening diplomatic ties between African nations and fostering cooperation on key issues.',
                'content_fr': "Plusieurs accords bilatéraux signés lors du sommet, renforçant les liens diplomatiques entre les nations africaines et favorisant la coopération sur des questions clés.",
                'author': 'Diplomacy Desk',
                'category_key': 'diplomacy',
                'publish_date': '2026-01-18T11:00:00Z',
                'is_featured': False,
            },
            {
                'title': 'Youth Empowerment: Africa\'s Future',
                'title_fr': "Autonomisation des jeunes: L'avenir de l'Afrique",
                'content': 'A special session dedicated to youth empowerment highlighted innovative programs and opportunities for young Africans across the continent.',
                'content_fr': "Une session spéciale dédiée à l'autonomisation des jeunes a mis en lumière des programmes innovants et des opportunités pour les jeunes Africains à travers le continent.",
                'author': 'Youth Affairs',
                'category_key': 'politics',
                'publish_date': '2026-01-15T08:00:00Z',
                'is_featured': False,
            },
        ]
        for art in articles:
            cat_key = art.pop('category_key')
            art['category'] = category_map.get(cat_key)
            Article.objects.get_or_create(title=art['title'], defaults=art)
        self.stdout.write(f'  {len(articles)} Articles created')

        # Embassy Locations
        embassies = [
            {
                'name': 'Embassy of Burundi - Addis Ababa',
                'name_fr': 'Ambassade du Burundi - Addis-Abeba',
                'address': 'Bole Road, Addis Ababa',
                'city': 'Addis Ababa',
                'country': 'Ethiopia',
                'latitude': 9.0054,
                'longitude': 38.7636,
                'phone_number': '+251 11 651 3422',
                'email': 'embassy.addis@burundi.gov.bi',
                'opening_hours': 'Mon-Fri: 8:00 AM - 5:00 PM',
                'type': 'embassy',
            },
            {
                'name': 'Burundi Consulate - Nairobi',
                'name_fr': 'Consulat du Burundi - Nairobi',
                'address': 'Ngong Road, Nairobi',
                'city': 'Nairobi',
                'country': 'Kenya',
                'latitude': -1.2864,
                'longitude': 36.8172,
                'phone_number': '+254 20 271 8681',
                'email': 'consulate.nairobi@burundi.gov.bi',
                'opening_hours': 'Mon-Fri: 9:00 AM - 4:00 PM',
                'type': 'consulate',
            },
            {
                'name': 'Embassy of Burundi - Brussels',
                'name_fr': 'Ambassade du Burundi - Bruxelles',
                'address': 'Square Marie-Louise 46, Brussels',
                'city': 'Brussels',
                'country': 'Belgium',
                'latitude': 50.8479,
                'longitude': 4.3740,
                'phone_number': '+32 2 230 45 35',
                'email': 'embassy.brussels@burundi.gov.bi',
                'opening_hours': 'Mon-Fri: 9:00 AM - 5:00 PM',
                'type': 'embassy',
            },
            {
                'name': 'Embassy of Burundi - Washington DC',
                'name_fr': 'Ambassade du Burundi - Washington DC',
                'address': '2233 Wisconsin Ave NW, Washington, DC',
                'city': 'Washington DC',
                'country': 'United States',
                'latitude': 38.9212,
                'longitude': -77.0703,
                'phone_number': '+1 202 342 2574',
                'email': 'embassy.dc@burundi.gov.bi',
                'opening_hours': 'Mon-Fri: 9:00 AM - 5:00 PM',
                'type': 'embassy',
            },
        ]
        for emb in embassies:
            EmbassyLocation.objects.get_or_create(
                name=emb['name'], city=emb['city'], defaults=emb,
            )
        self.stdout.write(f'  {len(embassies)} Embassy Locations created')

        # Events
        events = [
            {
                'name': 'AU Summit Opening Ceremony',
                'name_fr': "Cérémonie d'ouverture du Sommet de l'UA",
                'description': 'The official opening ceremony of the African Union Summit hosted by Burundi.',
                'description_fr': "La cérémonie officielle d'ouverture du Sommet de l'Union Africaine organisé par le Burundi.",
                'address': 'Bujumbura Convention Center',
                'latitude': -3.3614,
                'longitude': 29.3599,
                'event_date': '2026-02-10T09:00:00Z',
            },
            {
                'name': 'Cultural Exhibition',
                'name_fr': 'Exposition culturelle',
                'description': "Exhibition showcasing Burundi's cultural heritage and artistic traditions.",
                'description_fr': "Exposition présentant le patrimoine culturel et les traditions artistiques du Burundi.",
                'address': 'National Museum, Bujumbura',
                'latitude': -3.3784,
                'longitude': 29.3644,
                'event_date': '2026-02-11T10:00:00Z',
            },
            {
                'name': 'Economic Forum',
                'name_fr': 'Forum économique',
                'description': 'A forum discussing economic development and trade across Africa.',
                'description_fr': "Un forum discutant du développement économique et du commerce à travers l'Afrique.",
                'address': 'Trade Center, Bujumbura',
                'latitude': -3.3734,
                'longitude': 29.3544,
                'event_date': '2026-02-12T09:00:00Z',
            },
        ]
        for ev in events:
            Event.objects.get_or_create(name=ev['name'], defaults=ev)
        self.stdout.write(f'  {len(events)} Events created')

        # Live Feeds
        feeds = [
            {
                'title': 'AU Summit Opening Ceremony',
                'title_fr': "Cérémonie d'ouverture du Sommet de l'UA",
                'stream_url': 'https://stream.example.com/au-summit-opening',
                'status': 'live',
                'viewer_count': 15420,
            },
            {
                'title': 'Cultural Performance: Karyenda Drummers',
                'title_fr': 'Performance culturelle: Tambourinaires du Karyenda',
                'stream_url': 'https://stream.example.com/karyenda',
                'status': 'live',
                'viewer_count': 8750,
            },
            {
                'title': 'Economic Forum Discussion',
                'title_fr': 'Discussion du Forum économique',
                'stream_url': 'https://stream.example.com/economic-forum',
                'status': 'upcoming',
                'viewer_count': 0,
                'scheduled_time': timezone.now() + timezone.timedelta(hours=2),
            },
            {
                'title': 'Youth Leadership Summit',
                'title_fr': 'Sommet du leadership des jeunes',
                'stream_url': 'https://stream.example.com/youth-summit',
                'status': 'upcoming',
                'viewer_count': 0,
                'scheduled_time': timezone.now() + timezone.timedelta(hours=5),
            },
            {
                'title': 'Press Conference - Day 1',
                'title_fr': 'Conférence de presse - Jour 1',
                'stream_url': 'https://stream.example.com/press-day1',
                'status': 'recorded',
                'viewer_count': 25000,
                'duration': '1h 30m',
            },
            {
                'title': 'Welcome Reception',
                'title_fr': 'Réception de bienvenue',
                'stream_url': 'https://stream.example.com/welcome',
                'status': 'recorded',
                'viewer_count': 18500,
                'duration': '2h',
            },
            {
                'title': 'Ministerial Roundtable on Zoom',
                'title_fr': 'Table ronde ministérielle sur Zoom',
                'stream_url': 'https://zoom.us/j/1234567890',
                'status': 'upcoming',
                'viewer_count': 0,
                'scheduled_time': timezone.now() + timezone.timedelta(hours=8),
                'meeting_id': '123 456 7890',
                'passcode': 'AU2026',
            },
            {
                'title': 'Climate Action Working Group',
                'title_fr': 'Groupe de travail sur l\'action climatique',
                'stream_url': 'https://teams.microsoft.com/l/meetup-join/example',
                'status': 'upcoming',
                'viewer_count': 0,
                'scheduled_time': timezone.now() + timezone.timedelta(hours=12),
            },
        ]
        for feed in feeds:
            LiveFeed.objects.get_or_create(title=feed['title'], defaults=feed)
        self.stdout.write(f'  {len(feeds)} Live Feeds created')

        # Resources
        resources = [
            {'title': 'AU Summit Agenda 2026', 'title_fr': "Agenda du Sommet de l'UA 2026", 'category': 'official_documents', 'file_size': '2.4 MB', 'file_type': 'pdf'},
            {'title': 'Chairmanship Vision Statement', 'title_fr': 'Déclaration de vision de la présidence', 'category': 'official_documents', 'file_size': '1.8 MB', 'file_type': 'pdf'},
            {'title': 'Summit Declaration', 'title_fr': 'Déclaration du sommet', 'category': 'official_documents', 'file_size': '3.1 MB', 'file_type': 'pdf'},
            {'title': 'Burundi Fact Sheet', 'title_fr': 'Fiche pays du Burundi', 'category': 'country_info', 'file_size': '1.2 MB', 'file_type': 'pdf'},
            {'title': 'Tourism Guide', 'title_fr': 'Guide touristique', 'category': 'country_info', 'file_size': '5.6 MB', 'file_type': 'pdf'},
            {'title': 'Cultural Heritage', 'title_fr': 'Patrimoine culturel', 'category': 'country_info', 'file_size': '4.2 MB', 'file_type': 'pdf'},
            {'title': 'Press Kit', 'title_fr': 'Dossier de presse', 'category': 'media', 'file_size': '45 MB', 'file_type': 'zip'},
            {'title': 'Official Photos', 'title_fr': 'Photos officielles', 'category': 'media', 'file_size': '120 MB', 'file_type': 'zip'},
            {'title': 'Logo Package', 'title_fr': 'Pack logos', 'category': 'media', 'file_size': '15 MB', 'file_type': 'zip'},
            {'title': 'Protocol Guidelines', 'title_fr': 'Directives de protocole', 'category': 'reference', 'file_size': '890 KB', 'file_type': 'pdf'},
            {'title': 'Venue Maps', 'title_fr': 'Plans des lieux', 'category': 'reference', 'file_size': '6.3 MB', 'file_type': 'pdf'},
            {'title': 'Emergency Procedures', 'title_fr': "Procédures d'urgence", 'category': 'reference', 'file_size': '1.5 MB', 'file_type': 'pdf'},
        ]
        for res in resources:
            Resource.objects.get_or_create(title=res['title'], defaults=res)
        self.stdout.write(f'  {len(resources)} Resources created')

        # Priority Agendas
        priority_agendas = [
            {
                'title': 'Water & Sanitation',
                'title_fr': 'Eau et assainissement',
                'slug': 'water-sanitation',
                'description': 'Clean water access and sanitation infrastructure for all African communities',
                'description_fr': 'Accès à l\'eau potable et infrastructures d\'assainissement pour toutes les communautés africaines',
                'overview': 'Access to clean water and proper sanitation is a fundamental human right and a cornerstone of public health and economic development. Under Burundi\'s Be 4 Africa, we are committed to accelerating progress towards universal water and sanitation coverage across Africa.\n\nOur vision is clear: by 2030, every African should have access to safe drinking water and adequate sanitation facilities. This ambitious goal requires coordinated action, innovative financing, and strong political will from all member states.',
                'overview_fr': 'L\'accès à l\'eau potable et à un assainissement adéquat est un droit humain fondamental et un pilier de la santé publique et du développement économique. Sous la présidence burundaise de l\'UA, nous nous engageons à accélérer les progrès vers une couverture universelle en eau et assainissement à travers l\'Afrique.\n\nNotre vision est claire: d\'ici 2030, chaque Africain devrait avoir accès à l\'eau potable et à des installations d\'assainissement adéquates.',
                'objectives': [
                    'Achieve universal access to safe and affordable drinking water for all Africans by 2030',
                    'Ensure adequate and equitable sanitation and hygiene for all, with special focus on women and girls',
                    'Improve water quality by reducing pollution and minimizing release of hazardous chemicals',
                    'Substantially increase water-use efficiency across all sectors and ensure sustainable withdrawals',
                    'Implement integrated water resources management at all levels, including through transboundary cooperation',
                    'Protect and restore water-related ecosystems including mountains, forests, wetlands, rivers, and lakes'
                ],
                'objectives_fr': [
                    'Réaliser l\'accès universel à l\'eau potable sûre et abordable pour tous les Africains d\'ici 2030',
                    'Assurer un assainissement et une hygiène adéquats et équitables pour tous',
                    'Améliorer la qualité de l\'eau en réduisant la pollution',
                    'Augmenter considérablement l\'efficacité de l\'utilisation de l\'eau dans tous les secteurs'
                ],
                'impact_areas': [
                    {'icon': 'health_and_safety', 'title': 'Public Health', 'description': 'Reducing waterborne diseases, improving maternal and child health outcomes, and building healthier communities.'},
                    {'icon': 'school', 'title': 'Education', 'description': 'Enabling school attendance, particularly for girls, through provision of adequate sanitation facilities.'},
                    {'icon': 'agriculture', 'title': 'Agriculture & Food Security', 'description': 'Supporting sustainable irrigation, increasing crop yields, and enhancing food production capacity.'},
                    {'icon': 'trending_up', 'title': 'Economic Growth', 'description': 'Creating jobs in water infrastructure, boosting productivity, and enabling industrial development.'}
                ],
                'impact_areas_fr': [
                    {'icon': 'health_and_safety', 'title': 'Santé publique', 'description': 'Réduction des maladies d\'origine hydrique et amélioration de la santé.'},
                    {'icon': 'school', 'title': 'Éducation', 'description': 'Permettre la scolarisation grâce à des installations sanitaires adéquates.'},
                    {'icon': 'agriculture', 'title': 'Agriculture', 'description': 'Soutenir l\'irrigation durable et la sécurité alimentaire.'},
                    {'icon': 'trending_up', 'title': 'Croissance économique', 'description': 'Création d\'emplois et développement industriel.'}
                ],
                'current_initiatives': 'The African Union has launched several flagship initiatives including the Africa Water Investment Program, Regional Water Infrastructure Development, Cross-Border Water Cooperation Framework, and Innovation in Water Technology. These programs are mobilizing billions in investment and bringing together governments, development partners, and the private sector.',
                'current_initiatives_fr': 'L\'Union africaine a lancé plusieurs initiatives phares pour mobiliser des investissements et rassembler les gouvernements et le secteur privé.',
                'icon_name': 'water_drop',
                'display_order': 1,
                'is_active': True
            },
            {
                'title': 'A-RISE Initiative',
                'title_fr': 'Initiative A-RISE',
                'slug': 'arise-initiative',
                'description': 'Africa Rising Initiative for Sustainable Economy - Building economic resilience and prosperity',
                'description_fr': 'Initiative africaine pour une économie durable - Construire la résilience économique et la prospérité',
                'overview': 'The Africa Rising Initiative for Sustainable Economy (A-RISE) represents a transformative approach to African economic development. It is built on the understanding that sustainable economic growth must be inclusive, environmentally conscious, and driven by African solutions to African challenges.\n\nA-RISE aims to unlock Africa\'s vast economic potential through strategic investments in infrastructure, technology, human capital, and intra-African trade. By 2035, we envision an Africa that is economically integrated, technologically advanced, and globally competitive.',
                'overview_fr': 'L\'Initiative africaine pour une économie durable (A-RISE) représente une approche transformatrice du développement économique africain. Elle vise à libérer le vaste potentiel économique de l\'Afrique.',
                'objectives': [
                    'Accelerate infrastructure development across transport, energy, digital, and urban sectors',
                    'Promote industrialization and value addition to raw materials within Africa',
                    'Enhance regional integration and boost intra-African trade to 25% by 2030',
                    'Foster innovation and technology adoption in key economic sectors',
                    'Develop skills and capacities to meet the demands of modern economies',
                    'Mobilize domestic and international resources for sustainable development financing'
                ],
                'objectives_fr': [
                    'Accélérer le développement des infrastructures',
                    'Promouvoir l\'industrialisation et la valeur ajoutée',
                    'Renforcer l\'intégration régionale',
                    'Favoriser l\'innovation et l\'adoption technologique'
                ],
                'impact_areas': [
                    {'icon': 'business', 'title': 'Trade & Investment', 'description': 'Implementing AfCFTA, reducing trade barriers, and creating a $3.4 trillion continental market.'},
                    {'icon': 'factory', 'title': 'Industrialization', 'description': 'Building manufacturing capacity, processing raw materials locally, and creating quality jobs.'},
                    {'icon': 'computer', 'title': 'Digital Economy', 'description': 'Expanding internet access, promoting fintech, and harnessing technology for development.'},
                    {'icon': 'local_shipping', 'title': 'Infrastructure', 'description': 'Developing transport corridors, energy networks, and smart cities across the continent.'}
                ],
                'impact_areas_fr': [
                    {'icon': 'business', 'title': 'Commerce', 'description': 'Mise en œuvre de la ZLECAf et création d\'un marché continental.'},
                    {'icon': 'factory', 'title': 'Industrialisation', 'description': 'Développement des capacités manufacturières.'},
                    {'icon': 'computer', 'title': 'Économie numérique', 'description': 'Expansion de l\'accès à Internet et promotion des fintechs.'},
                    {'icon': 'local_shipping', 'title': 'Infrastructure', 'description': 'Développement de corridors de transport et de villes intelligentes.'}
                ],
                'current_initiatives': 'Key programs include the Continental Infrastructure Fund, African Digital Transformation Strategy, AfCFTA Implementation Support, Industrial Parks Development Program, and Youth Entrepreneurship & Innovation Hubs.',
                'current_initiatives_fr': 'Les programmes clés incluent le Fonds d\'infrastructure continental et la Stratégie de transformation numérique africaine.',
                'icon_name': 'trending_up',
                'display_order': 2,
                'is_active': True
            },
            {
                'title': 'Peace & Security',
                'title_fr': 'Paix et sécurité',
                'slug': 'peace-security',
                'description': 'Silencing the Guns and building lasting peace across Africa',
                'description_fr': 'Faire taire les armes et construire une paix durable en Afrique',
                'overview': 'Peace and security remain fundamental prerequisites for Africa\'s development and prosperity. Under our chairmanship, we are reinvigorating the African Union\'s commitment to "Silencing the Guns" and building sustainable peace across the continent.\n\nOur approach is comprehensive: preventing conflicts before they start, mediating disputes peacefully, supporting post-conflict reconstruction, and addressing the root causes of instability including poverty, inequality, and weak governance.',
                'overview_fr': 'La paix et la sécurité restent des conditions préalables fondamentales pour le développement de l\'Afrique. Notre approche est globale: prévenir les conflits, médier les différends et reconstruire après les conflits.',
                'objectives': [
                    'Achieve the "Silencing the Guns" goal and end armed conflicts across Africa',
                    'Strengthen early warning systems and conflict prevention mechanisms',
                    'Enhance mediation and peacebuilding capacities at continental and regional levels',
                    'Combat terrorism, violent extremism, and transnational organized crime',
                    'Support post-conflict reconstruction, reconciliation, and transitional justice',
                    'Address root causes of conflict including governance deficits and socio-economic marginalization'
                ],
                'objectives_fr': [
                    'Réaliser l\'objectif "Faire taire les armes"',
                    'Renforcer les systèmes d\'alerte précoce',
                    'Améliorer les capacités de médiation',
                    'Lutter contre le terrorisme et l\'extrémisme violent'
                ],
                'impact_areas': [
                    {'icon': 'shield', 'title': 'Conflict Prevention', 'description': 'Early warning systems, preventive diplomacy, and addressing tensions before escalation.'},
                    {'icon': 'handshake', 'title': 'Mediation & Dialogue', 'description': 'AU-led peace processes, inclusive dialogue, and negotiated settlements.'},
                    {'icon': 'military_tech', 'title': 'Peacekeeping', 'description': 'African Standby Force, regional brigades, and UN partnership operations.'},
                    {'icon': 'gavel', 'title': 'Governance & Justice', 'description': 'Democratic institutions, rule of law, accountability, and transitional justice.'}
                ],
                'impact_areas_fr': [
                    {'icon': 'shield', 'title': 'Prévention', 'description': 'Systèmes d\'alerte précoce et diplomatie préventive.'},
                    {'icon': 'handshake', 'title': 'Médiation', 'description': 'Processus de paix dirigés par l\'UA et dialogue inclusif.'},
                    {'icon': 'military_tech', 'title': 'Maintien de la paix', 'description': 'Force africaine en attente et opérations de partenariat.'},
                    {'icon': 'gavel', 'title': 'Gouvernance', 'description': 'Institutions démocratiques et état de droit.'}
                ],
                'current_initiatives': 'Major initiatives include the AU Peace Fund, Silencing the Guns Campaign 2030, African Peace and Security Architecture (APSA) enhancement, Counter-Terrorism Framework, and Women, Peace and Security Agenda implementation.',
                'current_initiatives_fr': 'Les initiatives majeures incluent le Fonds pour la paix de l\'UA et la campagne Faire taire les armes 2030.',
                'icon_name': 'security',
                'display_order': 3,
                'is_active': True
            }
        ]
        for agenda in priority_agendas:
            PriorityAgenda.objects.get_or_create(slug=agenda['slug'], defaults=agenda)
        self.stdout.write(f'  {len(priority_agendas)} Priority Agendas created')

        # ── Gallery Albums + Photos ──────────────────────────────
        gallery_albums = [
            {
                'title': 'AU Summit 2026 Highlights',
                'title_fr': 'Points forts du Sommet de l\'UA 2026',
                'description': 'Photos from the African Union Summit held in Bujumbura',
                'description_fr': 'Photos du Sommet de l\'Union africaine tenu à Bujumbura',
                'photo_count': 24,
                'is_featured': True,
                'display_order': 1,
                'photos': [
                    {'caption': 'Opening ceremony of the AU Summit', 'caption_fr': 'Cérémonie d\'ouverture du Sommet de l\'UA', 'photographer': 'AU Media', 'display_order': 1},
                    {'caption': 'Heads of State group photo', 'caption_fr': 'Photo de groupe des chefs d\'État', 'photographer': 'AU Media', 'display_order': 2},
                    {'caption': 'Plenary session in progress', 'caption_fr': 'Session plénière en cours', 'photographer': 'AU Media', 'display_order': 3},
                ],
            },
            {
                'title': 'Cultural Heritage of Burundi',
                'title_fr': 'Patrimoine culturel du Burundi',
                'description': 'Traditional drumming, dance, and cultural celebrations',
                'description_fr': 'Tambours traditionnels, danse et célébrations culturelles',
                'photo_count': 18,
                'is_featured': True,
                'display_order': 2,
                'photos': [
                    {'caption': 'Karyenda royal drummers performance', 'caption_fr': 'Performance des tambourinaires royaux du Karyenda', 'photographer': 'Culture Ministry', 'display_order': 1},
                    {'caption': 'Traditional Intore dancers', 'caption_fr': 'Danseurs traditionnels Intore', 'photographer': 'Culture Ministry', 'display_order': 2},
                    {'caption': 'Artisan crafts exhibition', 'caption_fr': 'Exposition d\'artisanat', 'photographer': 'Culture Ministry', 'display_order': 3},
                ],
            },
            {
                'title': 'Infrastructure Development',
                'title_fr': 'Développement des infrastructures',
                'description': 'New roads, buildings, and development projects across Burundi',
                'description_fr': 'Nouvelles routes, bâtiments et projets de développement au Burundi',
                'photo_count': 15,
                'is_featured': False,
                'display_order': 3,
                'photos': [
                    {'caption': 'New convention center in Bujumbura', 'caption_fr': 'Nouveau centre de conventions à Bujumbura', 'photographer': 'Infrastructure Ministry', 'display_order': 1},
                    {'caption': 'Highway construction project', 'caption_fr': 'Projet de construction d\'autoroute', 'photographer': 'Infrastructure Ministry', 'display_order': 2},
                ],
            },
            {
                'title': 'Youth & Education',
                'title_fr': 'Jeunesse et éducation',
                'description': 'Schools, universities, and youth empowerment programs',
                'description_fr': 'Écoles, universités et programmes d\'autonomisation des jeunes',
                'photo_count': 12,
                'is_featured': False,
                'display_order': 4,
                'photos': [
                    {'caption': 'Youth leadership summit participants', 'caption_fr': 'Participants au sommet du leadership des jeunes', 'photographer': 'Youth Ministry', 'display_order': 1},
                    {'caption': 'University of Burundi new campus', 'caption_fr': 'Nouveau campus de l\'Université du Burundi', 'photographer': 'Education Ministry', 'display_order': 2},
                ],
            },
        ]
        for album_data in gallery_albums:
            photos_data = album_data.pop('photos')
            album, created = GalleryAlbum.objects.get_or_create(
                title=album_data['title'], defaults=album_data
            )
            if created:
                for photo in photos_data:
                    GalleryPhoto.objects.create(album=album, **photo)
        self.stdout.write(f'  {len(gallery_albums)} Gallery Albums created (with photos)')

        # Videos
        videos = [
            {
                'title': 'Be 4 Africa Opening Ceremony',
                'title_fr': 'Cérémonie d\'ouverture de la présidence de l\'UA',
                'description': 'Full coverage of the historic opening ceremony as Burundi assumes the Be 4 Africa',
                'description_fr': 'Couverture complète de la cérémonie d\'ouverture historique',
                'video_url': 'https://www.youtube.com/watch?v=example1',
                'duration': '1:45:30',
                'category': 'highlight',
                'publish_date': '2026-02-01',
                'is_featured': True,
                'view_count': 15420
            },
            {
                'title': 'President\'s Vision for Africa',
                'title_fr': 'Vision du Président pour l\'Afrique',
                'description': 'Presidential address outlining the vision and priorities for the chairmanship',
                'description_fr': 'Discours présidentiel exposant la vision et les priorités',
                'video_url': 'https://www.youtube.com/watch?v=example2',
                'duration': '32:15',
                'category': 'speech',
                'publish_date': '2026-02-02',
                'is_featured': True,
                'view_count': 8750
            },
            {
                'title': 'Burundi: Heart of Africa Documentary',
                'title_fr': 'Burundi: Cœur de l\'Afrique Documentaire',
                'description': 'Exploring Burundi\'s culture, history, and natural beauty',
                'description_fr': 'Explorer la culture, l\'histoire et la beauté naturelle du Burundi',
                'video_url': 'https://www.youtube.com/watch?v=example3',
                'duration': '28:40',
                'category': 'documentary',
                'publish_date': '2026-01-25',
                'is_featured': True,
                'view_count': 12300
            },
            {
                'title': 'AU Leaders Summit Roundtable',
                'title_fr': 'Table ronde des dirigeants de l\'UA',
                'description': 'Leaders discuss continental priorities and cooperation',
                'description_fr': 'Les dirigeants discutent des priorités continentales',
                'video_url': 'https://www.youtube.com/watch?v=example4',
                'duration': '1:15:20',
                'category': 'event',
                'publish_date': '2026-02-03',
                'is_featured': False,
                'view_count': 5640
            },
            {
                'title': 'Traditional Burundian Drumming Performance',
                'title_fr': 'Spectacle de tambours traditionnels burundais',
                'description': 'UNESCO-recognized drummers showcase Burundi\'s rich cultural heritage',
                'description_fr': 'Spectacle du patrimoine culturel riche du Burundi',
                'video_url': 'https://www.youtube.com/watch?v=example5',
                'duration': '8:45',
                'category': 'cultural',
                'publish_date': '2026-01-30',
                'is_featured': False,
                'view_count': 9200
            },
            {
                'title': 'Interview: AU Commissioner on Peace & Security',
                'title_fr': 'Interview: Commissaire de l\'UA à la Paix et Sécurité',
                'description': 'Exclusive interview on silencing the guns and continental security',
                'description_fr': 'Interview exclusive sur faire taire les armes',
                'video_url': 'https://www.youtube.com/watch?v=example6',
                'duration': '18:30',
                'category': 'interview',
                'publish_date': '2026-02-04',
                'is_featured': False,
                'view_count': 3850
            },
        ]
        for video in videos:
            Video.objects.get_or_create(title=video['title'], defaults=video)
        self.stdout.write(f'  {len(videos)} Videos created')

        # Social Media Links
        social_media = [
            {
                'platform': 'facebook',
                'display_name': 'Be 4 Africa',
                'display_name_fr': 'Présidence UA du Burundi',
                'url': 'https://facebook.com/BurundiAU2026',
                'handle': '@BurundiAU2026',
                'follower_count': '125K',
                'description': 'Official Facebook page for updates and news',
                'description_fr': 'Page Facebook officielle pour les mises à jour',
                'icon_color': '#1877F2',
                'is_active': True,
                'display_order': 1
            },
            {
                'platform': 'twitter',
                'display_name': 'Burundi AU 2026',
                'display_name_fr': 'Burundi UA 2026',
                'url': 'https://twitter.com/BurundiAU2026',
                'handle': '@BurundiAU2026',
                'follower_count': '89K',
                'description': 'Follow us for real-time updates and live coverage',
                'description_fr': 'Suivez-nous pour des mises à jour en temps réel',
                'icon_color': '#1DA1F2',
                'is_active': True,
                'display_order': 2
            },
            {
                'platform': 'instagram',
                'display_name': 'Be 4 Africa',
                'display_name_fr': 'Présidence UA du Burundi',
                'url': 'https://instagram.com/burundiauchair2026',
                'handle': '@burundiauchair2026',
                'follower_count': '67K',
                'description': 'Photos and stories from Be 4 Africa',
                'description_fr': 'Photos et histoires de la présidence',
                'icon_color': '#E4405F',
                'is_active': True,
                'display_order': 3
            },
            {
                'platform': 'youtube',
                'display_name': 'Burundi AU 2026',
                'display_name_fr': 'Burundi UA 2026',
                'url': 'https://youtube.com/@BurundiAU2026',
                'handle': '@BurundiAU2026',
                'follower_count': '45K',
                'description': 'Video content, speeches, and documentaries',
                'description_fr': 'Vidéos, discours et documentaires',
                'icon_color': '#FF0000',
                'is_active': True,
                'display_order': 4
            },
            {
                'platform': 'linkedin',
                'display_name': 'Be 4 Africa',
                'display_name_fr': 'Présidence UA du Burundi 2026',
                'url': 'https://linkedin.com/company/burundi-au-chairmanship',
                'handle': 'Be 4 Africa',
                'follower_count': '28K',
                'description': 'Professional network and policy updates',
                'description_fr': 'Réseau professionnel et mises à jour politiques',
                'icon_color': '#0A66C2',
                'is_active': True,
                'display_order': 5
            },
        ]
        for sm in social_media:
            SocialMediaLink.objects.get_or_create(platform=sm['platform'], defaults=sm)
        self.stdout.write(f'  {len(social_media)} Social Media Links created')

        # Weather Cities
        weather_cities = [
            {
                'name': 'Bujumbura',
                'latitude': -3.3731,
                'longitude': 29.3644,
                'order': 1,
                'is_default': True,
                'is_active': True,
            },
            {
                'name': 'Addis Ababa',
                'latitude': 9.0192,
                'longitude': 38.7525,
                'order': 2,
                'is_default': True,
                'is_active': True,
            },
        ]
        for city in weather_cities:
            WeatherCity.objects.get_or_create(name=city['name'], defaults=city)
        self.stdout.write(f'  {len(weather_cities)} Weather Cities created')

        # Notifications
        notifications = [
            {
                'title': 'Welcome to Be 4 Africa 2026',
                'title_fr': 'Bienvenue à la Présidence de l\'UA du Burundi 2026',
                'message': 'Stay updated with the latest news, events, and announcements from the African Union Summit.',
                'message_fr': 'Restez informé des dernières nouvelles, événements et annonces du Sommet de l\'Union Africaine.',
                'notification_type': 'system',
                'action_type': 'none',
                'is_active': True,
            },
            {
                'title': 'AU Summit 2026 - Opening Ceremony',
                'title_fr': 'Sommet UA 2026 - Cérémonie d\'ouverture',
                'message': 'The AU Summit will officially open on February 15, 2026. Don\'t miss the historic event!',
                'message_fr': 'Le Sommet de l\'UA s\'ouvrira officiellement le 15 février 2026. Ne manquez pas cet événement historique !',
                'notification_type': 'event',
                'action_type': 'route',
                'action_value': '/calendar',
                'is_active': True,
            },
            {
                'title': 'New Magazine Edition Available',
                'title_fr': 'Nouvelle édition du magazine disponible',
                'message': 'Read the latest edition featuring insights on Africa\'s development agenda and regional integration.',
                'message_fr': 'Lisez la dernière édition avec des perspectives sur l\'agenda de développement de l\'Afrique et l\'intégration régionale.',
                'notification_type': 'magazine',
                'action_type': 'route',
                'action_value': '/magazine',
                'is_active': True,
            },
            {
                'title': 'Live Stream: Presidential Address',
                'title_fr': 'Diffusion en direct : Discours présidentiel',
                'message': 'Watch live as President Ndayishimiye addresses the Continental Summit. Starting soon!',
                'message_fr': 'Regardez en direct le Président Ndayishimiye s\'adresser au Sommet Continental. Commence bientôt !',
                'notification_type': 'article',
                'action_type': 'route',
                'action_value': '/live-feeds',
                'is_active': True,
            },
        ]
        for notif in notifications:
            Notification.objects.get_or_create(
                title=notif['title'],
                defaults=notif
            )
        self.stdout.write(f'  {len(notifications)} Notifications created')

        # ── Standalone Event Registrations ────────────────────────
        event_registrations = [
            {
                'event_title': 'AU Summit Gala Dinner',
                'event_title_fr': "Dîner de gala du Sommet de l'UA",
                'event_description': 'Join world leaders and delegates for an exclusive gala dinner celebrating African unity and the Be 4 Africa. Formal attire required.',
                'event_description_fr': "Rejoignez les dirigeants du monde et les délégués pour un dîner de gala exclusif célébrant l'unité africaine et la présidence burundaise de l'UA. Tenue formelle requise.",
                'card_type': 'event',
                'event_date': '2026-02-14T19:00:00Z',
                'event_end_date': '2026-02-14T23:00:00Z',
                'venue': 'Bujumbura Convention Center',
                'venue_fr': 'Centre de Conventions de Bujumbura',
                'venue_address': 'Boulevard de l\'Uprona, Bujumbura, Burundi',
                'contact_email': 'events@burundi.gov.bi',
                'contact_phone': '+257 22 22 34 56',
                'is_registration_enabled': True,
                'max_registrations': 500,
                'allow_proxy_registration': True,
                'confirmation_message': 'Thank you for registering! You will receive your invitation card by email within 48 hours.',
                'confirmation_message_fr': "Merci pour votre inscription ! Vous recevrez votre carte d'invitation par email dans les 48 heures.",
                'order': 1,
                'form_fields': [
                    {'field_type': 'text', 'field_label': 'Full Name', 'field_label_fr': 'Nom complet', 'field_name': 'full_name', 'is_required': True, 'order': 1},
                    {'field_type': 'email', 'field_label': 'Email Address', 'field_label_fr': 'Adresse email', 'field_name': 'email', 'is_required': True, 'order': 2},
                    {'field_type': 'nationality', 'field_label': 'Nationality', 'field_label_fr': 'Nationalité', 'field_name': 'nationality', 'is_required': True, 'order': 3},
                    {'field_type': 'text', 'field_label': 'Organization', 'field_label_fr': 'Organisation', 'field_name': 'organization', 'is_required': False, 'order': 4},
                    {'field_type': 'select', 'field_label': 'Dietary Preference', 'field_label_fr': 'Préférence alimentaire', 'field_name': 'dietary', 'is_required': False, 'order': 5, 'options': ['No restrictions', 'Vegetarian', 'Vegan', 'Halal', 'Other']},
                ],
            },
            {
                'event_title': 'Youth Innovation Forum',
                'event_title_fr': "Forum d'Innovation des Jeunes",
                'event_description': 'A two-day forum bringing together young innovators, entrepreneurs, and change-makers from across Africa. Pitch your ideas, network with industry leaders, and compete for seed funding.',
                'event_description_fr': "Un forum de deux jours réunissant de jeunes innovateurs, entrepreneurs et acteurs du changement de toute l'Afrique. Présentez vos idées, réseautez et concourez pour un financement de démarrage.",
                'card_type': 'event',
                'event_date': '2026-02-16T08:00:00Z',
                'event_end_date': '2026-02-17T17:00:00Z',
                'venue': 'University of Burundi Auditorium',
                'venue_fr': "Auditorium de l'Université du Burundi",
                'venue_address': 'Avenue de l\'UNESCO, Bujumbura, Burundi',
                'contact_email': 'youth@burundi.gov.bi',
                'contact_phone': '+257 22 22 78 90',
                'is_registration_enabled': True,
                'max_registrations': 200,
                'allow_proxy_registration': False,
                'confirmation_message': 'Welcome to the Youth Innovation Forum! Please bring a valid ID on the day of the event.',
                'confirmation_message_fr': "Bienvenue au Forum d'Innovation des Jeunes ! Veuillez apporter une pièce d'identité valide le jour de l'événement.",
                'order': 2,
                'form_fields': [
                    {'field_type': 'text', 'field_label': 'Full Name', 'field_label_fr': 'Nom complet', 'field_name': 'full_name', 'is_required': True, 'order': 1},
                    {'field_type': 'email', 'field_label': 'Email', 'field_label_fr': 'Email', 'field_name': 'email', 'is_required': True, 'order': 2},
                    {'field_type': 'phone', 'field_label': 'Phone Number', 'field_label_fr': 'Numéro de téléphone', 'field_name': 'phone', 'is_required': True, 'order': 3},
                    {'field_type': 'number', 'field_label': 'Age', 'field_label_fr': 'Âge', 'field_name': 'age', 'is_required': True, 'order': 4},
                    {'field_type': 'textarea', 'field_label': 'Tell us about your innovation project', 'field_label_fr': "Parlez-nous de votre projet d'innovation", 'field_name': 'project_description', 'is_required': True, 'order': 5},
                ],
            },
        ]
        for er_data in event_registrations:
            form_fields_data = er_data.pop('form_fields')
            er, created = EventRegistration.objects.get_or_create(
                event_title=er_data['event_title'], defaults=er_data
            )
            if created:
                for ff in form_fields_data:
                    RegistrationFormField.objects.create(event_registration=er, **ff)
        self.stdout.write(f'  {len(event_registrations)} Event Registrations created (with form fields)')

        # ── SOS Quick Access Item ──────────────────────────────────
        QuickAccessMenuItem.objects.get_or_create(
            title_en='SOS',
            defaults={
                'title_fr': 'SOS',
                'icon_name': 'sos',
                'action_type': 'route',
                'action_value': '/emergency',
                'order': 8,
                'is_active': True,
                'badge_text': '',
                'badge_color': '#E53935',
            },
        )
        self.stdout.write('  SOS Quick Access item created')

        # ── Emergency Contacts ────────────────────────────────────
        emergency_contacts = [
            {'name_en': 'Police', 'name_fr': 'Police', 'description_en': 'National Police', 'description_fr': 'Police Nationale', 'icon_name': 'local_police', 'category': 'police', 'action_type': 'call', 'contact_value': '117', 'color': '#1565C0', 'order': 1},
            {'name_en': 'Fire Department', 'name_fr': 'Pompiers', 'description_en': 'Fire & Rescue', 'description_fr': 'Secours incendie', 'icon_name': 'local_fire_department', 'category': 'fire', 'action_type': 'call', 'contact_value': '118', 'color': '#E53935', 'order': 2},
            {'name_en': 'Ambulance', 'name_fr': 'Ambulance', 'description_en': 'Emergency Medical', 'description_fr': 'Urgences médicales', 'icon_name': 'medical_services', 'category': 'medical', 'action_type': 'call', 'contact_value': '115', 'color': '#2E7D32', 'order': 3},
            {'name_en': 'App Support', 'name_fr': 'Assistance', 'description_en': 'In-app support', 'description_fr': 'Assistance dans l\'app', 'icon_name': 'support_agent', 'category': 'support', 'action_type': 'route', 'contact_value': '/support', 'color': '#6A1B9A', 'order': 4},
        ]
        for ec in emergency_contacts:
            EmergencyContact.objects.get_or_create(name_en=ec['name_en'], defaults=ec)
        self.stdout.write(f'  {len(emergency_contacts)} Emergency Contacts created')

        self.stdout.write(self.style.SUCCESS('\nAll data seeded successfully!'))
