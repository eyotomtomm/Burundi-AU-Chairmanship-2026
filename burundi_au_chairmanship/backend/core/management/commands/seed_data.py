from django.contrib.auth.models import User
from django.core.management.base import BaseCommand
from django.utils import timezone
from core.models import (
    Article, MagazineEdition, EmbassyLocation, Event,
    LiveFeed, Resource, AppSettings,
    FeatureCard, HeroSlide, PriorityAgenda, GalleryAlbum,
    GalleryPhoto, Video, SocialMediaLink, Category,
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
        ]
        for fc in feature_cards:
            FeatureCard.objects.get_or_create(title=fc['title'], defaults=fc)
        self.stdout.write(f'  {len(feature_cards)} Feature Cards created')

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
                'description': "Complete coverage of the AU Summit and Burundi's chairmanship.",
                'description_fr': "Couverture complète du Sommet de l'UA et de la présidence du Burundi.",
                'publish_date': '2026-02-01',
                'is_featured': True,
                'external_url': 'https://au.int/sites/default/files/documents/summit-report-2026.pdf',
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
                'external_url': 'https://au.int/sites/default/files/documents/burundi-nation-rising.pdf',
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
                'external_url': 'https://au.int/sites/default/files/documents/african-unity-action.pdf',
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
                'overview': 'Access to clean water and proper sanitation is a fundamental human right and a cornerstone of public health and economic development. Under Burundi\'s AU Chairmanship, we are committed to accelerating progress towards universal water and sanitation coverage across Africa.\n\nOur vision is clear: by 2030, every African should have access to safe drinking water and adequate sanitation facilities. This ambitious goal requires coordinated action, innovative financing, and strong political will from all member states.',
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
                'title': 'AU Chairmanship Opening Ceremony',
                'title_fr': 'Cérémonie d\'ouverture de la présidence de l\'UA',
                'description': 'Full coverage of the historic opening ceremony as Burundi assumes the AU Chairmanship',
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
                'display_name': 'Burundi AU Chairmanship',
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
                'display_name': 'Burundi AU Chairmanship',
                'display_name_fr': 'Présidence UA du Burundi',
                'url': 'https://instagram.com/burundiauchair2026',
                'handle': '@burundiauchair2026',
                'follower_count': '67K',
                'description': 'Photos and stories from the AU Chairmanship',
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
                'display_name': 'Burundi AU Chairmanship 2026',
                'display_name_fr': 'Présidence UA du Burundi 2026',
                'url': 'https://linkedin.com/company/burundi-au-chairmanship',
                'handle': 'Burundi AU Chairmanship',
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

        self.stdout.write(self.style.SUCCESS('\nAll data seeded successfully!'))
