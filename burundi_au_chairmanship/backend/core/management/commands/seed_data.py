from django.contrib.auth.models import User
from django.core.management.base import BaseCommand
from django.utils import timezone
from core.models import (
    Article, MagazineEdition, EmbassyLocation, Event,
    LiveFeed, Resource, EmergencyContact, AppSettings,
    FeatureCard, HeroSlide,
)


class Command(BaseCommand):
    help = 'Seed the database with initial data'

    def handle(self, *args, **options):
        self.stdout.write('Seeding data...')

        # Admin user
        if not User.objects.filter(is_superuser=True).exists():
            User.objects.create_superuser('admin', 'admin@burundi.gov.bi', 'admin2026')
            self.stdout.write('  Admin user created (admin / admin2026)')

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
            {'label': 'Burundi AU Chairmanship 2026', 'label_fr': 'Présidence UA du Burundi 2026', 'order': 1},
            {'label': 'Building a Resilient Africa', 'label_fr': 'Construire une Afrique résiliente', 'order': 2},
            {'label': 'Unity in Diversity', 'label_fr': 'Unité dans la diversité', 'order': 3},
            {'label': 'A Prosperous Continent', 'label_fr': 'Un continent prospère', 'order': 4},
        ]
        for slide in hero_slides:
            HeroSlide.objects.get_or_create(label=slide['label'], defaults=slide)
        self.stdout.write(f'  {len(hero_slides)} Hero Slides created')

        # Feature Cards
        feature_cards = [
            {
                'title': 'AU Summit 2026',
                'title_fr': 'Sommet UA 2026',
                'description': 'Follow the African Union Summit live with updates and coverage.',
                'description_fr': "Suivez le Sommet de l'Union Africaine en direct avec des mises à jour et une couverture.",
                'gradient_start': '#1EB53A',
                'gradient_end': '#4CAF50',
                'order': 1,
            },
            {
                'title': 'Discover Burundi',
                'title_fr': 'Découvrir le Burundi',
                'description': "Explore Burundi's rich culture, history, and natural beauty.",
                'description_fr': 'Explorez la riche culture, l\'histoire et la beauté naturelle du Burundi.',
                'gradient_start': '#CE1126',
                'gradient_end': '#E57373',
                'order': 2,
            },
            {
                'title': 'Consular Services',
                'title_fr': 'Services consulaires',
                'description': 'Access visa, passport, and other consular services online.',
                'description_fr': 'Accédez aux services de visa, passeport et autres services consulaires en ligne.',
                'gradient_start': '#D4AF37',
                'gradient_end': '#FFD54F',
                'order': 3,
            },
        ]
        for fc in feature_cards:
            FeatureCard.objects.get_or_create(title=fc['title'], defaults=fc)
        self.stdout.write(f'  {len(feature_cards)} Feature Cards created')

        # Magazine Editions
        editions = [
            {
                'title': 'AU Summit Special Edition',
                'title_fr': "Édition spéciale du Sommet de l'UA",
                'description': "Complete coverage of the AU Summit and Burundi's chairmanship.",
                'description_fr': "Couverture complète du Sommet de l'UA et de la présidence du Burundi.",
                'publish_date': '2026-02-01',
                'is_featured': True,
            },
            {
                'title': 'Burundi: A Nation Rising',
                'title_fr': 'Burundi: Une nation en essor',
                'description': "Exploring Burundi's economic growth and development initiatives.",
                'description_fr': 'Explorer la croissance économique et les initiatives de développement du Burundi.',
                'publish_date': '2026-01-15',
                'is_featured': False,
            },
            {
                'title': 'African Unity in Action',
                'title_fr': "L'unité africaine en action",
                'description': 'How African nations are working together for continental progress.',
                'description_fr': 'Comment les nations africaines travaillent ensemble pour le progrès continental.',
                'publish_date': '2026-01-01',
                'is_featured': False,
            },
        ]
        for ed in editions:
            MagazineEdition.objects.get_or_create(title=ed['title'], defaults=ed)
        self.stdout.write(f'  {len(editions)} Magazine Editions created')

        # Articles
        articles = [
            {
                'title': 'Burundi Takes the Helm of African Union',
                'title_fr': "Le Burundi prend la tête de l'Union Africaine",
                'content': "In a historic moment, Burundi assumes the chairmanship of the African Union, marking a new chapter in the nation's diplomatic journey. President Ndayishimiye outlined an ambitious agenda focused on economic integration, peace and security, and youth empowerment across the continent.",
                'content_fr': "Dans un moment historique, le Burundi assume la présidence de l'Union Africaine, marquant un nouveau chapitre dans le parcours diplomatique de la nation. Le Président Ndayishimiye a présenté un agenda ambitieux axé sur l'intégration économique, la paix et la sécurité, et l'autonomisation des jeunes à travers le continent.",
                'author': 'AU Press Office',
                'category': 'politics',
                'publish_date': '2026-02-01T10:00:00Z',
                'is_featured': True,
            },
            {
                'title': 'Economic Development Initiatives for Africa',
                'title_fr': "Initiatives de développement économique pour l'Afrique",
                'content': 'New economic policies aim to boost trade and investment across the African continent, with a focus on digital transformation and sustainable agriculture.',
                'content_fr': "De nouvelles politiques économiques visent à stimuler le commerce et les investissements à travers le continent africain, avec un accent sur la transformation numérique et l'agriculture durable.",
                'author': 'Economic Desk',
                'category': 'economy',
                'publish_date': '2026-01-28T14:00:00Z',
                'is_featured': True,
            },
            {
                'title': 'Cultural Heritage Celebration at the Summit',
                'title_fr': 'Célébration du patrimoine culturel au Sommet',
                'content': "A grand celebration of Burundi's rich cultural heritage takes center stage at the summit, featuring the legendary Karyenda drummers and traditional dance performances.",
                'content_fr': "Une grande célébration du riche patrimoine culturel du Burundi occupe le devant de la scène lors du sommet, mettant en vedette les légendaires tambourinaires du Karyenda et des spectacles de danse traditionnelle.",
                'author': 'Culture Editor',
                'category': 'culture',
                'publish_date': '2026-01-20T09:00:00Z',
                'is_featured': False,
            },
            {
                'title': 'Diplomatic Relations Strengthened',
                'title_fr': 'Relations diplomatiques renforcées',
                'content': 'Multiple bilateral agreements signed during the summit, strengthening diplomatic ties between African nations and fostering cooperation on key issues.',
                'content_fr': "Plusieurs accords bilatéraux signés lors du sommet, renforçant les liens diplomatiques entre les nations africaines et favorisant la coopération sur des questions clés.",
                'author': 'Diplomacy Desk',
                'category': 'diplomacy',
                'publish_date': '2026-01-18T11:00:00Z',
                'is_featured': False,
            },
            {
                'title': 'Youth Empowerment: Africa\'s Future',
                'title_fr': "Autonomisation des jeunes: L'avenir de l'Afrique",
                'content': 'A special session dedicated to youth empowerment highlighted innovative programs and opportunities for young Africans across the continent.',
                'content_fr': "Une session spéciale dédiée à l'autonomisation des jeunes a mis en lumière des programmes innovants et des opportunités pour les jeunes Africains à travers le continent.",
                'author': 'Youth Affairs',
                'category': 'politics',
                'publish_date': '2026-01-15T08:00:00Z',
                'is_featured': False,
            },
        ]
        for art in articles:
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

        # Emergency Contacts
        contacts = [
            {'name': 'Embassy', 'name_fr': 'Ambassade', 'phone_number': '+257 22 22 34 54', 'type': 'embassy', 'order': 1},
            {'name': 'Police', 'name_fr': 'Police', 'phone_number': '117', 'type': 'police', 'order': 2},
            {'name': 'Ambulance', 'name_fr': 'Ambulance', 'phone_number': '118', 'type': 'ambulance', 'order': 3},
            {'name': 'Fire Department', 'name_fr': 'Pompiers', 'phone_number': '118', 'type': 'fire', 'order': 4},
        ]
        for c in contacts:
            EmergencyContact.objects.get_or_create(type=c['type'], defaults=c)
        self.stdout.write(f'  {len(contacts)} Emergency Contacts created')

        self.stdout.write(self.style.SUCCESS('\nAll data seeded successfully!'))
