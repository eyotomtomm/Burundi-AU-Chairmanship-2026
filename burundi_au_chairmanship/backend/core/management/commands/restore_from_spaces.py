"""
Restore database records from existing DigitalOcean Spaces files.

Run this after seed_data to link existing media files to database records.
Usage: python manage.py restore_from_spaces
"""
from django.core.management.base import BaseCommand
from django.db.models.signals import pre_save
from django.utils import timezone
from core.models import (
    Article, MagazineEdition, Event, LiveFeed,
    FeatureCard, HeroSlide, GalleryAlbum, GalleryPhoto,
    Video, Notification, Category, _auto_optimize_image,
)


class Command(BaseCommand):
    help = 'Restore database records pointing to existing DO Spaces media files'

    def handle(self, *args, **options):
        self.stdout.write('Restoring records from Spaces media files...\n')

        # Disconnect the image optimization signal so we can save records
        # that reference existing Spaces files without downloading them
        models_to_disconnect = [
            HeroSlide, Article, Event, FeatureCard, MagazineEdition,
            GalleryAlbum, GalleryPhoto, LiveFeed, Video, Notification,
        ]
        for model in models_to_disconnect:
            pre_save.disconnect(_auto_optimize_image, sender=model)
        self.stdout.write('  Image optimization signal disconnected')

        # ── Categories (needed for articles) ─────────────────────
        cat_politics, _ = Category.objects.get_or_create(
            name='Politics', defaults={'name_fr': 'Politique', 'color': '#CE1126', 'order': 0})
        cat_economy, _ = Category.objects.get_or_create(
            name='Economy', defaults={'name_fr': 'Économie', 'color': '#17a2b8', 'order': 1})
        cat_culture, _ = Category.objects.get_or_create(
            name='Culture', defaults={'name_fr': 'Culture', 'color': '#D4AF37', 'order': 2})
        cat_diplomacy, _ = Category.objects.get_or_create(
            name='Diplomacy', defaults={'name_fr': 'Diplomatie', 'color': '#1EB53A', 'order': 3})
        self.stdout.write(self.style.SUCCESS('  Categories ready'))

        # ── Hero Slides ──────────────────────────────────────────
        hero_slides = [
            {'image': 'hero_slides/IMG_1647.jpeg', 'label': 'Burundi AU Chairmanship 2026', 'label_fr': 'Présidence UA du Burundi 2026', 'order': 1},
            {'image': 'hero_slides/IMG_1648.jpeg', 'label': 'Building a Resilient Africa', 'label_fr': 'Construire une Afrique résiliente', 'order': 2},
            {'image': 'hero_slides/IMG20260326095325.jpg', 'label': 'Unity in Diversity', 'label_fr': 'Unité dans la diversité', 'order': 3},
            {'image': 'hero_slides/Final_version_1.jpg', 'label': 'A Prosperous Continent', 'label_fr': 'Un continent prospère', 'order': 4},
            {'image': 'hero_slides/IMG_3545.jpeg', 'label': 'Africa We Want', 'label_fr': "L'Afrique que nous voulons", 'order': 5},
            {'image': 'hero_slides/Norway_1.jpg', 'label': 'International Cooperation', 'label_fr': 'Coopération internationale', 'order': 6},
            {'image': 'hero_slides/Norwey_2.jpg', 'label': 'Diplomatic Excellence', 'label_fr': 'Excellence diplomatique', 'order': 7},
        ]
        created = 0
        for hs in hero_slides:
            _, was_created = HeroSlide.objects.get_or_create(
                image=hs['image'], defaults=hs)
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f'  {created} Hero Slides created'))

        # ── Articles ─────────────────────────────────────────────
        articles = [
            {
                'image': 'articles/IMG_1646.jpeg',
                'title': 'Burundi Takes the Helm of African Union',
                'title_fr': "Le Burundi prend la tête de l'Union Africaine",
                'content': "In a historic moment, Burundi assumes the chairmanship of the African Union, marking a new chapter in the nation's diplomatic journey. President Ndayishimiye outlined an ambitious agenda focused on economic integration, peace and security, and youth empowerment across the continent.",
                'content_fr': "Dans un moment historique, le Burundi assume la présidence de l'Union Africaine, marquant un nouveau chapitre dans le parcours diplomatique de la nation.",
                'author': 'AU Press Office', 'category': cat_politics, 'is_featured': True,
                'publish_date': '2026-02-01T10:00:00Z',
            },
            {
                'image': 'articles/IMG_1649.jpeg',
                'title': 'Economic Development Initiatives for Africa',
                'title_fr': "Initiatives de développement économique pour l'Afrique",
                'content': 'New economic policies aim to boost trade and investment across the African continent, with a focus on digital transformation and sustainable agriculture.',
                'content_fr': "De nouvelles politiques économiques visent à stimuler le commerce et les investissements à travers le continent africain.",
                'author': 'Economic Desk', 'category': cat_economy, 'is_featured': True,
                'publish_date': '2026-01-28T14:00:00Z',
            },
            {
                'image': 'articles/IMG_1650.jpeg',
                'title': 'Cultural Heritage Celebration at the Summit',
                'title_fr': 'Célébration du patrimoine culturel au Sommet',
                'content': "A grand celebration of Burundi's rich cultural heritage takes center stage at the summit, featuring the legendary Karyenda drummers and traditional dance performances.",
                'content_fr': "Une grande célébration du riche patrimoine culturel du Burundi occupe le devant de la scène lors du sommet.",
                'author': 'Culture Editor', 'category': cat_culture, 'is_featured': False,
                'publish_date': '2026-01-20T09:00:00Z',
            },
            {
                'image': 'articles/IMG_1651.jpeg',
                'title': 'Diplomatic Relations Strengthened Across the Continent',
                'title_fr': 'Relations diplomatiques renforcées à travers le continent',
                'content': 'Multiple bilateral agreements signed during the summit, strengthening diplomatic ties between African nations and fostering cooperation on key issues.',
                'content_fr': "Plusieurs accords bilatéraux signés lors du sommet, renforçant les liens diplomatiques entre les nations africaines.",
                'author': 'Diplomacy Desk', 'category': cat_diplomacy, 'is_featured': False,
                'publish_date': '2026-01-18T11:00:00Z',
            },
            {
                'image': 'articles/IMG_1652.jpeg',
                'title': "Youth Empowerment: Africa's Future",
                'title_fr': "Autonomisation des jeunes: L'avenir de l'Afrique",
                'content': 'A special session dedicated to youth empowerment highlighted innovative programs and opportunities for young Africans across the continent.',
                'content_fr': "Une session spéciale dédiée à l'autonomisation des jeunes a mis en lumière des programmes innovants.",
                'author': 'Youth Affairs', 'category': cat_politics, 'is_featured': False,
                'publish_date': '2026-01-15T08:00:00Z',
            },
            {
                'image': 'articles/IMG_1653.jpeg',
                'title': 'Infrastructure Development: Building Africa Together',
                'title_fr': "Développement des infrastructures: Construire l'Afrique ensemble",
                'content': 'Major infrastructure projects across the continent are driving economic growth, connecting communities, and creating opportunities for millions of Africans.',
                'content_fr': "Des projets d'infrastructure majeurs à travers le continent stimulent la croissance économique.",
                'author': 'Infrastructure Desk', 'category': cat_economy, 'is_featured': True,
                'publish_date': '2026-01-12T10:00:00Z',
            },
            {
                'image': 'articles/IMG_1654.jpeg',
                'title': 'Health Initiatives Across the African Union',
                'title_fr': "Initiatives de santé à travers l'Union Africaine",
                'content': 'The AU launches comprehensive healthcare programs aimed at improving access to medical services and strengthening public health systems across member states.',
                'content_fr': "L'UA lance des programmes de santé complets visant à améliorer l'accès aux services médicaux.",
                'author': 'Health Desk', 'category': cat_politics, 'is_featured': False,
                'publish_date': '2026-01-10T09:00:00Z',
            },
            {
                'image': 'articles/IMG_1655.jpeg',
                'title': 'Education for All: Continental Strategy',
                'title_fr': "Éducation pour tous: Stratégie continentale",
                'content': 'A new continental education strategy focuses on quality education, digital literacy, and vocational training for Africa\'s growing young population.',
                'content_fr': "Une nouvelle stratégie continentale d'éducation met l'accent sur la qualité de l'éducation et la formation professionnelle.",
                'author': 'Education Desk', 'category': cat_culture, 'is_featured': False,
                'publish_date': '2026-01-08T14:00:00Z',
            },
            {
                'image': 'articles/IMG_1656.jpeg',
                'title': 'Climate Action: Africa Leading the Way',
                'title_fr': "Action climatique: L'Afrique montre la voie",
                'content': 'African nations are taking bold steps to combat climate change, investing in renewable energy and sustainable development practices.',
                'content_fr': "Les nations africaines prennent des mesures audacieuses pour lutter contre le changement climatique.",
                'author': 'Environment Desk', 'category': cat_economy, 'is_featured': False,
                'publish_date': '2026-01-05T11:00:00Z',
            },
            {
                'image': 'articles/IMG_1657.jpeg',
                'title': 'Technology and Innovation Hub in Bujumbura',
                'title_fr': "Pôle technologique et d'innovation à Bujumbura",
                'content': 'Bujumbura is emerging as a technology hub in East Africa, with new startups and innovation centers driving digital transformation.',
                'content_fr': "Bujumbura émerge comme un pôle technologique en Afrique de l'Est.",
                'author': 'Tech Desk', 'category': cat_economy, 'is_featured': True,
                'publish_date': '2026-01-03T10:00:00Z',
            },
            {
                'image': 'articles/IMG_1658.jpeg',
                'title': 'Peace and Security: A Continental Priority',
                'title_fr': 'Paix et sécurité: Une priorité continentale',
                'content': 'The African Union reaffirms its commitment to silencing the guns and achieving lasting peace across the continent through dialogue and cooperation.',
                'content_fr': "L'Union Africaine réaffirme son engagement à faire taire les armes et à parvenir à une paix durable.",
                'author': 'Peace & Security', 'category': cat_diplomacy, 'is_featured': False,
                'publish_date': '2026-01-01T09:00:00Z',
            },
            {
                'image': 'articles/IMG_1660.jpeg',
                'title': 'Agricultural Revolution in Burundi',
                'title_fr': 'Révolution agricole au Burundi',
                'content': 'Burundi is transforming its agricultural sector with modern farming techniques, improving food security and boosting exports of premium coffee and tea.',
                'content_fr': "Le Burundi transforme son secteur agricole avec des techniques modernes.",
                'author': 'Agriculture Desk', 'category': cat_economy, 'is_featured': False,
                'publish_date': '2025-12-28T10:00:00Z',
            },
            {
                'image': 'articles/IMG_1661.jpeg',
                'title': "Women's Empowerment at the Heart of the Agenda",
                'title_fr': "Autonomisation des femmes au cœur de l'agenda",
                'content': "The chairmanship prioritizes gender equality and women's empowerment, recognizing the crucial role women play in Africa's development.",
                'content_fr': "La présidence accorde la priorité à l'égalité des genres et à l'autonomisation des femmes.",
                'author': 'Gender Affairs', 'category': cat_politics, 'is_featured': False,
                'publish_date': '2025-12-25T14:00:00Z',
            },
            {
                'image': 'articles/IMG_1665.png',
                'title': 'AU Summit Preparations in Full Swing',
                'title_fr': 'Préparatifs du Sommet de l\'UA en plein essor',
                'content': 'Preparations for the African Union Summit are progressing rapidly with state-of-the-art venues and world-class facilities being readied in Bujumbura.',
                'content_fr': "Les préparatifs du Sommet de l'Union Africaine progressent rapidement.",
                'author': 'AU Press Office', 'category': cat_politics, 'is_featured': True,
                'publish_date': '2025-12-22T10:00:00Z',
            },
            {
                'image': 'articles/IMG_1667.jpeg',
                'title': 'Tourism Boom: Discovering Burundi',
                'title_fr': 'Boom touristique: Découvrir le Burundi',
                'content': "Tourism in Burundi is experiencing unprecedented growth as the country showcases its natural beauty, from Lake Tanganyika to the lush Kibira National Park.",
                'content_fr': "Le tourisme au Burundi connaît une croissance sans précédent.",
                'author': 'Tourism Desk', 'category': cat_culture, 'is_featured': False,
                'publish_date': '2025-12-20T09:00:00Z',
            },
            {
                'image': 'articles/IMG_1668.jpeg',
                'title': 'Regional Trade Integration Accelerates',
                'title_fr': "L'intégration commerciale régionale s'accélère",
                'content': 'East African nations are deepening trade cooperation, with Burundi playing a key role in advancing the African Continental Free Trade Area.',
                'content_fr': "Les nations d'Afrique de l'Est approfondissent la coopération commerciale.",
                'author': 'Trade Desk', 'category': cat_diplomacy, 'is_featured': False,
                'publish_date': '2025-12-18T11:00:00Z',
            },
        ]
        created = 0
        for art in articles:
            _, was_created = Article.objects.get_or_create(
                title=art['title'], defaults=art)
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f'  {created} Articles created'))

        # ── Events ───────────────────────────────────────────────
        events = [
            {
                'image': 'events/IMG_1663.jpeg',
                'name': 'AU Summit Opening Ceremony',
                'name_fr': "Cérémonie d'ouverture du Sommet de l'UA",
                'description': 'The official opening ceremony of the African Union Summit hosted by Burundi.',
                'description_fr': "La cérémonie officielle d'ouverture du Sommet de l'Union Africaine organisé par le Burundi.",
                'address': 'Bujumbura Convention Center',
                'latitude': -3.3614, 'longitude': 29.3599,
                'event_date': '2026-02-10T09:00:00Z',
            },
            {
                'image': 'events/IMG_1664.jpeg',
                'name': 'Cultural Exhibition',
                'name_fr': 'Exposition culturelle',
                'description': "Exhibition showcasing Burundi's cultural heritage and artistic traditions.",
                'description_fr': "Exposition présentant le patrimoine culturel et les traditions artistiques du Burundi.",
                'address': 'National Museum, Bujumbura',
                'latitude': -3.3784, 'longitude': 29.3644,
                'event_date': '2026-02-11T10:00:00Z',
            },
        ]
        created = 0
        for ev in events:
            _, was_created = Event.objects.get_or_create(
                name=ev['name'], defaults=ev)
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f'  {created} Events created'))

        # ── Feature Cards ────────────────────────────────────────
        feature_cards = [
            {
                'image': 'feature_cards/IMG20260326095325.jpg',
                'icon_image': 'feature_cards/icons/IMG_1673.jpeg',
                'title': 'AU Summit 2026',
                'title_fr': 'Sommet UA 2026',
                'description': 'Follow the African Union Summit live with updates and coverage.',
                'description_fr': "Suivez le Sommet de l'Union Africaine en direct.",
                'gradient_start': '#1EB53A', 'gradient_end': '#4CAF50',
                'icon_name': 'stars', 'action_type': 'route', 'action_value': '/feature-detail', 'order': 1,
            },
            {
                'image': 'feature_cards/e3023ecf-f1dc-4df2-9dc4-0155745452c2.jpeg',
                'title': 'Discover Burundi',
                'title_fr': 'Découvrir le Burundi',
                'description': "Explore Burundi's rich culture, history, and natural beauty.",
                'description_fr': "Explorez la riche culture, l'histoire et la beauté naturelle du Burundi.",
                'gradient_start': '#CE1126', 'gradient_end': '#E57373',
                'icon_name': 'travel_explore', 'action_type': 'route', 'action_value': '/feature-detail', 'order': 2,
            },
            {
                'image': 'feature_cards/3fa9b25e-473a-41b6-a570-0f2bceed0611.jpeg',
                'title': 'African Unity',
                'title_fr': 'Unité Africaine',
                'description': 'Celebrating the spirit of Pan-African unity and cooperation.',
                'description_fr': "Célébrer l'esprit d'unité panafricaine et de coopération.",
                'gradient_start': '#D4AF37', 'gradient_end': '#FFD54F',
                'icon_name': 'public', 'action_type': 'route', 'action_value': '/feature-detail', 'order': 3,
            },
        ]
        created = 0
        for fc in feature_cards:
            _, was_created = FeatureCard.objects.get_or_create(
                title=fc['title'], defaults=fc)
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f'  {created} Feature Cards created'))

        # ── Magazines ────────────────────────────────────────────
        magazines = [
            {
                'cover_image': 'magazines/IMG_1662.jpeg',
                'pdf_file': 'magazines/pdfs/Ineza_Info_compressed.pdf',
                'title': 'Ineza Info',
                'title_fr': 'Ineza Info',
                'description': 'Official Burundi Chairmanship magazine covering AU news and developments.',
                'description_fr': 'Magazine officiel de la présidence du Burundi couvrant les nouvelles de l\'UA.',
                'publish_date': '2026-02-01',
                'is_featured': True,
                'file_size': '35.8 MB',
            },
            {
                'cover_image': 'magazines/IMG_1669.jpeg',
                'pdf_file': 'magazines/pdfs/ingomag_008_Compressed.pdf',
                'title': 'Ingo Magazine',
                'title_fr': 'Ingo Magazine',
                'description': 'Exploring African unity, culture, and the path to continental prosperity.',
                'description_fr': "Explorer l'unité africaine, la culture et le chemin vers la prospérité continentale.",
                'publish_date': '2026-01-15',
                'is_featured': True,
                'file_size': '94.4 MB',
            },
        ]
        created = 0
        for mag in magazines:
            _, was_created = MagazineEdition.objects.get_or_create(
                title=mag['title'], defaults=mag)
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f'  {created} Magazines created'))

        # ── Live Feeds ───────────────────────────────────────────
        live_feeds = [
            {
                'thumbnail': 'live_feeds/Final_version.jpg',
                'title': 'AU Summit Live Coverage',
                'title_fr': 'Couverture en direct du Sommet de l\'UA',
                'stream_url': 'https://www.youtube.com/watch?v=example1',
                'status': 'recorded', 'viewer_count': 15420, 'duration': '2h 30m',
            },
            {
                'thumbnail': 'live_feeds/IMG_1671.jpeg',
                'title': 'Cultural Performance: Karyenda Drummers',
                'title_fr': 'Performance culturelle: Tambourinaires du Karyenda',
                'stream_url': 'https://www.youtube.com/watch?v=example2',
                'status': 'recorded', 'viewer_count': 8750, 'duration': '1h 15m',
            },
        ]
        created = 0
        for lf in live_feeds:
            _, was_created = LiveFeed.objects.get_or_create(
                title=lf['title'], defaults=lf)
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f'  {created} Live Feeds created'))

        # ── Gallery Albums & Photos ──────────────────────────────
        albums = [
            {
                'cover_image': 'gallery/covers/IMG_2658.jpeg',
                'title': 'AU Summit 2026 Highlights',
                'title_fr': 'Points forts du Sommet de l\'UA 2026',
                'description': 'Photos from the African Union Summit held in Bujumbura',
                'description_fr': 'Photos du Sommet de l\'Union africaine tenu à Bujumbura',
                'is_featured': True, 'display_order': 1,
                'photos': [
                    'gallery/photos/IMG_2691.jpeg',
                    'gallery/photos/IMG_2695.jpeg',
                    'gallery/photos/IMG_2697.jpeg',
                    'gallery/photos/IMG_2700.jpeg',
                    'gallery/photos/IMG_2714.jpeg',
                ],
            },
            {
                'cover_image': 'gallery/covers/IMG_3596.jpeg',
                'title': 'Cultural Heritage of Burundi',
                'title_fr': 'Patrimoine culturel du Burundi',
                'description': 'Traditional drumming, dance, and cultural celebrations',
                'description_fr': 'Tambours traditionnels, danse et célébrations culturelles',
                'is_featured': True, 'display_order': 2,
                'photos': [
                    'gallery/photos/IMG_3503.jpeg',
                    'gallery/photos/IMG_3505.jpeg',
                    'gallery/photos/IMG_3514.jpeg',
                    'gallery/photos/IMG_3523.jpeg',
                    'gallery/photos/IMG_3533.jpeg',
                    'gallery/photos/IMG_3545.jpeg',
                    'gallery/photos/IMG_3546.jpeg',
                    'gallery/photos/IMG_3565.jpeg',
                    'gallery/photos/IMG_3582.jpeg',
                    'gallery/photos/IMG_3591.jpeg',
                    'gallery/photos/IMG_3597.jpeg',
                    'gallery/photos/IMG_3598.jpeg',
                ],
            },
            {
                'cover_image': 'gallery/covers/2642c74e-1652-40c4-b2cb-083338039af7.jpeg',
                'title': 'Diplomatic Meetings',
                'title_fr': 'Réunions diplomatiques',
                'description': 'Key diplomatic meetings and bilateral discussions',
                'description_fr': 'Réunions diplomatiques clés et discussions bilatérales',
                'is_featured': False, 'display_order': 3,
                'photos': [
                    'gallery/photos/000164d0-4660-4d67-9982-8fbcf3093486.jpeg',
                    'gallery/photos/2642c74e-1652-40c4-b2cb-083338039af7.jpeg',
                    'gallery/photos/4d4fc527-98fa-4116-a4de-6c676e8e4561.jpeg',
                    'gallery/photos/83159463-13e4-4e00-baf7-6a6d0160f830.jpeg',
                    'gallery/photos/b1b4433e-fe88-4584-80ef-bfa5e88c4631.jpeg',
                    'gallery/photos/d6fd5b7f-5e21-4dbd-9218-d22750adbb37.jpeg',
                    'gallery/photos/e2fcd5fb-203d-4ba9-8588-49315412b125.jpeg',
                ],
            },
        ]
        created_albums = 0
        created_photos = 0
        for album_data in albums:
            photos = album_data.pop('photos')
            album, was_created = GalleryAlbum.objects.get_or_create(
                title=album_data['title'], defaults=album_data)
            if was_created:
                created_albums += 1
                # Use raw SQL to bypass GalleryPhoto.save() which tries to
                # open the image from S3 for compression
                from django.db import connection
                with connection.cursor() as cursor:
                    for i, photo_path in enumerate(photos):
                        cursor.execute(
                            "INSERT INTO core_galleryphoto (album_id, image, display_order, caption, caption_fr, photographer, created_at) "
                            "VALUES (%s, %s, %s, %s, %s, %s, NOW())",
                            [album.id, photo_path, i + 1, '', '', '']
                        )
                        created_photos += 1
                album.photo_count = len(photos)
                album.save(update_fields=['photo_count'])
        self.stdout.write(self.style.SUCCESS(
            f'  {created_albums} Gallery Albums, {created_photos} Photos created'))

        # ── Videos ───────────────────────────────────────────────
        videos = [
            {
                'thumbnail': 'videos/thumbnails/IMG_1670.jpeg',
                'title': 'Burundi Chairmanship Opening Ceremony',
                'title_fr': "Cérémonie d'ouverture de la présidence de l'UA",
                'description': 'Full coverage of the historic opening ceremony.',
                'description_fr': "Couverture complète de la cérémonie d'ouverture historique.",
                'video_url': 'https://www.youtube.com/watch?v=example1',
                'duration': '1:45:30', 'category': 'highlight',
                'publish_date': '2026-02-01', 'is_featured': True, 'view_count': 15420,
            },
        ]
        created = 0
        for vid in videos:
            _, was_created = Video.objects.get_or_create(
                title=vid['title'], defaults=vid)
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f'  {created} Videos created'))

        # ── Notifications ────────────────────────────────────────
        notifications = [
            {
                'image': 'notifications/Ambassador_of_Jordan_3.webp',
                'title': 'Ambassador of Jordan Visits Burundi',
                'title_fr': "L'Ambassadeur de Jordanie visite le Burundi",
                'message': 'The Ambassador of Jordan has arrived for bilateral discussions on strengthening diplomatic relations.',
                'message_fr': "L'Ambassadeur de Jordanie est arrivé pour des discussions bilatérales.",
                'notification_type': 'general', 'is_active': True,
            },
        ]
        created = 0
        for notif in notifications:
            _, was_created = Notification.objects.get_or_create(
                title=notif['title'], defaults=notif)
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f'  {created} Notifications created'))

        # ── Feature Card Media (agenda image) ────────────────────
        # The agendas/b4africa_big.jpg and feature_card_media/ files
        # are referenced by existing FeatureCard or PriorityAgenda records.
        # Update if they exist without images.
        from core.models import PriorityAgenda
        PriorityAgenda.objects.filter(slug='water-sanitation').update(
            image='agendas/b4africa_big.jpg') if hasattr(PriorityAgenda, 'image') else None

        # Reconnect the signal
        for model in models_to_disconnect:
            pre_save.connect(_auto_optimize_image, sender=model)

        self.stdout.write(self.style.SUCCESS(
            '\nAll records restored from Spaces! '
            'Log into admin to review and edit content.'
        ))
