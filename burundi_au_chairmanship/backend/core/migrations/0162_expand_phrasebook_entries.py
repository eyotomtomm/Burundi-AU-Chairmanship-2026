from django.db import migrations


def expand_phrasebook(apps, schema_editor):
    PhrasebookEntry = apps.get_model('core', 'PhrasebookEntry')

    entries = [
        # ══════════════════════════════════════════════════════════════
        #  GREETINGS  (continuing from display_order 15+)
        # ══════════════════════════════════════════════════════════════
        {'category': 'greetings', 'kirundi': 'Bwakeye', 'english': 'Good morning', 'french': 'Bonjour (matin)', 'display_order': 15},
        {'category': 'greetings', 'kirundi': 'Bwiriwe', 'english': 'Good afternoon', 'french': 'Bon après-midi', 'display_order': 16},
        {'category': 'greetings', 'kirundi': 'Ijoro ryiza', 'english': 'Good night', 'french': 'Bonne nuit', 'display_order': 17},
        {'category': 'greetings', 'kirundi': 'Witwa nde?', 'english': 'What is your name?', 'french': 'Comment vous appelez-vous ?', 'display_order': 18},
        {'category': 'greetings', 'kirundi': 'Nitwa ...', 'english': 'My name is ...', 'french': 'Je m\'appelle ...', 'display_order': 19},
        {'category': 'greetings', 'kirundi': 'Ndishimye kukumenya', 'english': 'Nice to meet you', 'french': 'Enchanté(e)', 'display_order': 20},
        {'category': 'greetings', 'kirundi': 'Umeze gute?', 'english': 'How are you? (informal)', 'french': 'Comment vas-tu ?', 'display_order': 21},
        {'category': 'greetings', 'kirundi': 'Mumeze gute?', 'english': 'How are you? (formal/plural)', 'french': 'Comment allez-vous ?', 'display_order': 22},
        {'category': 'greetings', 'kirundi': 'Ndameze neza', 'english': 'I am doing well', 'french': 'Je vais bien', 'display_order': 23},
        {'category': 'greetings', 'kirundi': 'Murabeho', 'english': 'Farewell (stay well)', 'french': 'Adieu (portez-vous bien)', 'display_order': 24},
        {'category': 'greetings', 'kirundi': 'Ngaho', 'english': 'Bye (casual)', 'french': 'Salut (au revoir)', 'display_order': 25},
        {'category': 'greetings', 'kirundi': 'N\'agahore', 'english': 'Please', 'french': 'S\'il vous plaît', 'display_order': 26},
        {'category': 'greetings', 'kirundi': 'Mbabarira', 'english': 'Excuse me / I\'m sorry', 'french': 'Excusez-moi / Pardon', 'display_order': 27},
        {'category': 'greetings', 'kirundi': 'Ntibikomeye', 'english': 'No problem / It\'s nothing', 'french': 'Pas de problème / De rien', 'display_order': 28},
        {'category': 'greetings', 'kirundi': 'Urakomeye?', 'english': 'Are you okay?', 'french': 'Ça va ?', 'display_order': 29},
        {'category': 'greetings', 'kirundi': 'Imana ibarinde', 'english': 'May God protect you', 'french': 'Que Dieu vous protège', 'display_order': 30},
        {'category': 'greetings', 'kirundi': 'Umunsi mwiza', 'english': 'Have a good day', 'french': 'Bonne journée', 'display_order': 31},
        {'category': 'greetings', 'kirundi': 'Urugendo rwiza', 'english': 'Have a good trip', 'french': 'Bon voyage', 'display_order': 32},
        {'category': 'greetings', 'kirundi': 'Uva he?', 'english': 'Where are you from?', 'french': 'D\'où venez-vous ?', 'display_order': 33},
        {'category': 'greetings', 'kirundi': 'Nva mu ...', 'english': 'I am from ...', 'french': 'Je viens de ...', 'display_order': 34},
        {'category': 'greetings', 'kirundi': 'Ndavuga icongereza', 'english': 'I speak English', 'french': 'Je parle anglais', 'display_order': 35},
        {'category': 'greetings', 'kirundi': 'Ndavuga igifaransa', 'english': 'I speak French', 'french': 'Je parle français', 'display_order': 36},
        {'category': 'greetings', 'kirundi': 'Sinavuga ikirundi', 'english': 'I don\'t speak Kirundi', 'french': 'Je ne parle pas le kirundi', 'display_order': 37},
        {'category': 'greetings', 'kirundi': 'Uvuga icongereza?', 'english': 'Do you speak English?', 'french': 'Parlez-vous anglais ?', 'display_order': 38},
        {'category': 'greetings', 'kirundi': 'Uvuga igifaransa?', 'english': 'Do you speak French?', 'french': 'Parlez-vous français ?', 'display_order': 39},
        {'category': 'greetings', 'kirundi': 'Ntabwo numva', 'english': 'I don\'t understand', 'french': 'Je ne comprends pas', 'display_order': 40},
        {'category': 'greetings', 'kirundi': 'Subira uvuge', 'english': 'Please repeat', 'french': 'Répétez, s\'il vous plaît', 'display_order': 41},
        {'category': 'greetings', 'kirundi': 'Vuga buhoro', 'english': 'Speak slowly', 'french': 'Parlez lentement', 'display_order': 42},
        {'category': 'greetings', 'kirundi': 'Ndabikeneye', 'english': 'I need help', 'french': 'J\'ai besoin d\'aide', 'display_order': 43},
        {'category': 'greetings', 'kirundi': 'Ni ryari?', 'english': 'When?', 'french': 'Quand ?', 'display_order': 44},
        {'category': 'greetings', 'kirundi': 'Ni gute?', 'english': 'How?', 'french': 'Comment ?', 'display_order': 45},
        {'category': 'greetings', 'kirundi': 'Kubera iki?', 'english': 'Why?', 'french': 'Pourquoi ?', 'display_order': 46},
        {'category': 'greetings', 'kirundi': 'Ni nde?', 'english': 'Who?', 'french': 'Qui ?', 'display_order': 47},
        {'category': 'greetings', 'kirundi': 'Ni iki?', 'english': 'What?', 'french': 'Quoi ?', 'display_order': 48},

        # ══════════════════════════════════════════════════════════════
        #  DIRECTIONS  (continuing from display_order 12+)
        # ══════════════════════════════════════════════════════════════
        {'category': 'directions', 'kirundi': 'Hejuru', 'english': 'Up / Above', 'french': 'En haut', 'display_order': 12},
        {'category': 'directions', 'kirundi': 'Hasi', 'english': 'Down / Below', 'french': 'En bas', 'display_order': 13},
        {'category': 'directions', 'kirundi': 'Hagati', 'english': 'In the middle / Between', 'french': 'Au milieu / Entre', 'display_order': 14},
        {'category': 'directions', 'kirundi': 'Iruhande', 'english': 'Beside / Next to', 'french': 'À côté de', 'display_order': 15},
        {'category': 'directions', 'kirundi': 'Imbere ya', 'english': 'In front of', 'french': 'Devant', 'display_order': 16},
        {'category': 'directions', 'kirundi': 'Inyuma ya', 'english': 'Behind (something)', 'french': 'Derrière (quelque chose)', 'display_order': 17},
        {'category': 'directions', 'kirundi': 'Ni hehe isoko?', 'english': 'Where is the market?', 'french': 'Où est le marché ?', 'display_order': 18},
        {'category': 'directions', 'kirundi': 'Ni hehe ibitaro?', 'english': 'Where is the hospital?', 'french': 'Où est l\'hôpital ?', 'display_order': 19},
        {'category': 'directions', 'kirundi': 'Ni hehe ambasade?', 'english': 'Where is the embassy?', 'french': 'Où est l\'ambassade ?', 'display_order': 20},
        {'category': 'directions', 'kirundi': 'Ni hehe igare?', 'english': 'Where is the bus station?', 'french': 'Où est la gare routière ?', 'display_order': 21},
        {'category': 'directions', 'kirundi': 'Ni hehe ibanki?', 'english': 'Where is the bank?', 'french': 'Où est la banque ?', 'display_order': 22},
        {'category': 'directions', 'kirundi': 'Ni hehe iresitora?', 'english': 'Where is the restaurant?', 'french': 'Où est le restaurant ?', 'display_order': 23},
        {'category': 'directions', 'kirundi': 'Ni hehe igisagara?', 'english': 'Where is the city center?', 'french': 'Où est le centre-ville ?', 'display_order': 24},
        {'category': 'directions', 'kirundi': 'Ni hehe umusigiti?', 'english': 'Where is the mosque?', 'french': 'Où est la mosquée ?', 'display_order': 25},
        {'category': 'directions', 'kirundi': 'Ni hehe ekleziya?', 'english': 'Where is the church?', 'french': 'Où est l\'église ?', 'display_order': 26},
        {'category': 'directions', 'kirundi': 'Hindura iburyo', 'english': 'Turn right', 'french': 'Tournez à droite', 'display_order': 27},
        {'category': 'directions', 'kirundi': 'Hindura ibubamfu', 'english': 'Turn left', 'french': 'Tournez à gauche', 'display_order': 28},
        {'category': 'directions', 'kirundi': 'Genda imbere', 'english': 'Go straight', 'french': 'Allez tout droit', 'display_order': 29},
        {'category': 'directions', 'kirundi': 'Hagarara hano', 'english': 'Stop here', 'french': 'Arrêtez-vous ici', 'display_order': 30},
        {'category': 'directions', 'kirundi': 'Ni kure cane?', 'english': 'Is it very far?', 'french': 'C\'est très loin ?', 'display_order': 31},
        {'category': 'directions', 'kirundi': 'Ni hafi', 'english': 'It is nearby', 'french': 'C\'est tout près', 'display_order': 32},
        {'category': 'directions', 'kirundi': 'Iminota ingahe?', 'english': 'How many minutes?', 'french': 'Combien de minutes ?', 'display_order': 33},
        {'category': 'directions', 'kirundi': 'Nyereka inzira', 'english': 'Show me the way', 'french': 'Montrez-moi le chemin', 'display_order': 34},
        {'category': 'directions', 'kirundi': 'Ni hehe toilette?', 'english': 'Where is the toilet?', 'french': 'Où sont les toilettes ?', 'display_order': 35},
        {'category': 'directions', 'kirundi': 'Mu buraruko', 'english': 'North', 'french': 'Nord', 'display_order': 36},
        {'category': 'directions', 'kirundi': 'Mu bumanuko', 'english': 'South', 'french': 'Sud', 'display_order': 37},
        {'category': 'directions', 'kirundi': 'Mu buseruko', 'english': 'East', 'french': 'Est', 'display_order': 38},
        {'category': 'directions', 'kirundi': 'Mu burengero', 'english': 'West', 'french': 'Ouest', 'display_order': 39},
        {'category': 'directions', 'kirundi': 'Ni hehe Centre de Conférence?', 'english': 'Where is the Conference Centre?', 'french': 'Où est le Centre de Conférence ?', 'display_order': 40},
        {'category': 'directions', 'kirundi': 'Ni hehe ikigo ca Leta?', 'english': 'Where is the government building?', 'french': 'Où est le bâtiment gouvernemental ?', 'display_order': 41},
        {'category': 'directions', 'kirundi': 'Ni hehe iposta?', 'english': 'Where is the post office?', 'french': 'Où est la poste ?', 'display_order': 42},
        {'category': 'directions', 'kirundi': 'Ni hehe ifarumasi?', 'english': 'Where is the pharmacy?', 'french': 'Où est la pharmacie ?', 'display_order': 43},
        {'category': 'directions', 'kirundi': 'Ni hehe aho bacisha ibinyamakuru?', 'english': 'Where is the press center?', 'french': 'Où est le centre de presse ?', 'display_order': 44},

        # ══════════════════════════════════════════════════════════════
        #  DIPLOMACY  (continuing from display_order 13+)
        # ══════════════════════════════════════════════════════════════
        {'category': 'diplomacy', 'kirundi': 'Umuyobozi', 'english': 'Leader / Director', 'french': 'Dirigeant / Directeur', 'display_order': 13},
        {'category': 'diplomacy', 'kirundi': 'Perezida', 'english': 'President', 'french': 'Président', 'display_order': 14},
        {'category': 'diplomacy', 'kirundi': 'Inama Nkuru', 'english': 'Summit / High-level meeting', 'french': 'Sommet', 'display_order': 15},
        {'category': 'diplomacy', 'kirundi': 'Ishirahamwe ry\'Ubumwe bw\'Afrika', 'english': 'African Union', 'french': 'Union africaine', 'display_order': 16},
        {'category': 'diplomacy', 'kirundi': 'Ubushikiranganji', 'english': 'Ministry', 'french': 'Ministère', 'display_order': 17},
        {'category': 'diplomacy', 'kirundi': 'Igihugu', 'english': 'Country / Nation', 'french': 'Pays / Nation', 'display_order': 18},
        {'category': 'diplomacy', 'kirundi': 'Umunyagihugu', 'english': 'Citizen', 'french': 'Citoyen', 'display_order': 19},
        {'category': 'diplomacy', 'kirundi': 'Agateka ka muntu', 'english': 'Human rights', 'french': 'Droits de l\'homme', 'display_order': 20},
        {'category': 'diplomacy', 'kirundi': 'Inyigisho', 'english': 'Resolution', 'french': 'Résolution', 'display_order': 21},
        {'category': 'diplomacy', 'kirundi': 'Icegeranyo', 'english': 'Report', 'french': 'Rapport', 'display_order': 22},
        {'category': 'diplomacy', 'kirundi': 'Ikiganiro', 'english': 'Dialogue / Discussion', 'french': 'Dialogue / Discussion', 'display_order': 23},
        {'category': 'diplomacy', 'kirundi': 'Ikiganiro gikuru', 'english': 'Continental dialogue', 'french': 'Dialogue continental', 'display_order': 24},
        {'category': 'diplomacy', 'kirundi': 'Inteko Ishinga Amategeko', 'english': 'Parliament', 'french': 'Parlement', 'display_order': 25},
        {'category': 'diplomacy', 'kirundi': 'Amategeko', 'english': 'Laws / Legislation', 'french': 'Lois / Législation', 'display_order': 26},
        {'category': 'diplomacy', 'kirundi': 'Itegeko Nshingiro', 'english': 'Constitution', 'french': 'Constitution', 'display_order': 27},
        {'category': 'diplomacy', 'kirundi': 'Ubutungane', 'english': 'Justice', 'french': 'Justice', 'display_order': 28},
        {'category': 'diplomacy', 'kirundi': 'Umutekano', 'english': 'Security', 'french': 'Sécurité', 'display_order': 29},
        {'category': 'diplomacy', 'kirundi': 'Ubumwe bw\'Abanyafrika', 'english': 'African unity', 'french': 'Unité africaine', 'display_order': 30},
        {'category': 'diplomacy', 'kirundi': 'Amajambere', 'english': 'Progress / Advancement', 'french': 'Progrès / Avancement', 'display_order': 31},
        {'category': 'diplomacy', 'kirundi': 'Ubumenyi', 'english': 'Knowledge / Education', 'french': 'Connaissance / Éducation', 'display_order': 32},
        {'category': 'diplomacy', 'kirundi': 'Impunzi', 'english': 'Refugees', 'french': 'Réfugiés', 'display_order': 33},
        {'category': 'diplomacy', 'kirundi': 'Ukwihanganira', 'english': 'Tolerance', 'french': 'Tolérance', 'display_order': 34},
        {'category': 'diplomacy', 'kirundi': 'Ukunywanisha', 'english': 'Reconciliation', 'french': 'Réconciliation', 'display_order': 35},
        {'category': 'diplomacy', 'kirundi': 'Inama y\'Abakuru b\'Ibihugu', 'english': 'Assembly of Heads of State', 'french': 'Assemblée des Chefs d\'État', 'display_order': 36},
        {'category': 'diplomacy', 'kirundi': 'Isekeza', 'english': 'Campaign / Initiative', 'french': 'Campagne / Initiative', 'display_order': 37},
        {'category': 'diplomacy', 'kirundi': 'Umukozi wa dipolomasi', 'english': 'Diplomat', 'french': 'Diplomate', 'display_order': 38},
        {'category': 'diplomacy', 'kirundi': 'Ambasaderi', 'english': 'Ambassador', 'french': 'Ambassadeur', 'display_order': 39},
        {'category': 'diplomacy', 'kirundi': 'Ambasade', 'english': 'Embassy', 'french': 'Ambassade', 'display_order': 40},
        {'category': 'diplomacy', 'kirundi': 'Konsila', 'english': 'Consulate', 'french': 'Consulat', 'display_order': 41},
        {'category': 'diplomacy', 'kirundi': 'Ibihugu bigize Afrika', 'english': 'African member states', 'french': 'États membres africains', 'display_order': 42},
        {'category': 'diplomacy', 'kirundi': 'Ikoperative', 'english': 'Cooperative', 'french': 'Coopérative', 'display_order': 43},
        {'category': 'diplomacy', 'kirundi': 'Ugufashanya', 'english': 'Mutual assistance', 'french': 'Entraide', 'display_order': 44},
        {'category': 'diplomacy', 'kirundi': 'Iteganyabikorwa', 'english': 'Agenda / Action plan', 'french': 'Agenda / Plan d\'action', 'display_order': 45},
        {'category': 'diplomacy', 'kirundi': 'Ivyiyumviro', 'english': 'Opinions / Views', 'french': 'Opinions / Points de vue', 'display_order': 46},
        {'category': 'diplomacy', 'kirundi': 'Ubuserukizi', 'english': 'Delegation / Representation', 'french': 'Délégation / Représentation', 'display_order': 47},
        {'category': 'diplomacy', 'kirundi': 'Ishirahamwe Mpuzamakungu', 'english': 'United Nations', 'french': 'Nations Unies', 'display_order': 48},
        {'category': 'diplomacy', 'kirundi': 'Ubushikiranganji bw\'ububanyi n\'amahanga', 'english': 'Ministry of Foreign Affairs', 'french': 'Ministère des Affaires étrangères', 'display_order': 49},
        {'category': 'diplomacy', 'kirundi': 'Igice c\'amahoro', 'english': 'Peace process', 'french': 'Processus de paix', 'display_order': 50},
        {'category': 'diplomacy', 'kirundi': 'Igihugu c\'Uburundi', 'english': 'The Republic of Burundi', 'french': 'La République du Burundi', 'display_order': 51},
        {'category': 'diplomacy', 'kirundi': 'Umuvugizi', 'english': 'Spokesperson', 'french': 'Porte-parole', 'display_order': 52},

        # ══════════════════════════════════════════════════════════════
        #  NUMBERS  (continuing from display_order 13+)
        # ══════════════════════════════════════════════════════════════
        {'category': 'numbers', 'kirundi': 'Cumi na rimwe', 'english': 'Eleven (11)', 'french': 'Onze (11)', 'display_order': 13},
        {'category': 'numbers', 'kirundi': 'Cumi na kabiri', 'english': 'Twelve (12)', 'french': 'Douze (12)', 'display_order': 14},
        {'category': 'numbers', 'kirundi': 'Cumi na gatatu', 'english': 'Thirteen (13)', 'french': 'Treize (13)', 'display_order': 15},
        {'category': 'numbers', 'kirundi': 'Cumi na kane', 'english': 'Fourteen (14)', 'french': 'Quatorze (14)', 'display_order': 16},
        {'category': 'numbers', 'kirundi': 'Cumi na gatanu', 'english': 'Fifteen (15)', 'french': 'Quinze (15)', 'display_order': 17},
        {'category': 'numbers', 'kirundi': 'Cumi na gatandatu', 'english': 'Sixteen (16)', 'french': 'Seize (16)', 'display_order': 18},
        {'category': 'numbers', 'kirundi': 'Cumi n\'indwi', 'english': 'Seventeen (17)', 'french': 'Dix-sept (17)', 'display_order': 19},
        {'category': 'numbers', 'kirundi': 'Cumi n\'umunani', 'english': 'Eighteen (18)', 'french': 'Dix-huit (18)', 'display_order': 20},
        {'category': 'numbers', 'kirundi': 'Cumi n\'icenda', 'english': 'Nineteen (19)', 'french': 'Dix-neuf (19)', 'display_order': 21},
        {'category': 'numbers', 'kirundi': 'Mirongo ibiri', 'english': 'Twenty (20)', 'french': 'Vingt (20)', 'display_order': 22},
        {'category': 'numbers', 'kirundi': 'Mirongo itatu', 'english': 'Thirty (30)', 'french': 'Trente (30)', 'display_order': 23},
        {'category': 'numbers', 'kirundi': 'Mirongo ine', 'english': 'Forty (40)', 'french': 'Quarante (40)', 'display_order': 24},
        {'category': 'numbers', 'kirundi': 'Mirongo itanu', 'english': 'Fifty (50)', 'french': 'Cinquante (50)', 'display_order': 25},
        {'category': 'numbers', 'kirundi': 'Mirongo itandatu', 'english': 'Sixty (60)', 'french': 'Soixante (60)', 'display_order': 26},
        {'category': 'numbers', 'kirundi': 'Mirongo irindwi', 'english': 'Seventy (70)', 'french': 'Soixante-dix (70)', 'display_order': 27},
        {'category': 'numbers', 'kirundi': 'Mirongo umunani', 'english': 'Eighty (80)', 'french': 'Quatre-vingts (80)', 'display_order': 28},
        {'category': 'numbers', 'kirundi': 'Mirongo icenda', 'english': 'Ninety (90)', 'french': 'Quatre-vingt-dix (90)', 'display_order': 29},
        {'category': 'numbers', 'kirundi': 'Amajana abiri', 'english': 'Two hundred (200)', 'french': 'Deux cents (200)', 'display_order': 30},
        {'category': 'numbers', 'kirundi': 'Amajana atanu', 'english': 'Five hundred (500)', 'french': 'Cinq cents (500)', 'display_order': 31},
        {'category': 'numbers', 'kirundi': 'Umuliyoni', 'english': 'One million (1,000,000)', 'french': 'Un million (1 000 000)', 'display_order': 32},
        # Ordinal numbers
        {'category': 'numbers', 'kirundi': 'Ubwa mbere', 'english': 'First', 'french': 'Premier / Première', 'display_order': 33},
        {'category': 'numbers', 'kirundi': 'Ubwa kabiri', 'english': 'Second', 'french': 'Deuxième', 'display_order': 34},
        {'category': 'numbers', 'kirundi': 'Ubwa gatatu', 'english': 'Third', 'french': 'Troisième', 'display_order': 35},
        {'category': 'numbers', 'kirundi': 'Ubwa kane', 'english': 'Fourth', 'french': 'Quatrième', 'display_order': 36},
        {'category': 'numbers', 'kirundi': 'Ubwa gatanu', 'english': 'Fifth', 'french': 'Cinquième', 'display_order': 37},
        # Time-related numbers
        {'category': 'numbers', 'kirundi': 'Isaha', 'english': 'Hour / O\'clock', 'french': 'Heure', 'display_order': 38},
        {'category': 'numbers', 'kirundi': 'Iminota', 'english': 'Minutes', 'french': 'Minutes', 'display_order': 39},
        {'category': 'numbers', 'kirundi': 'Isegonda', 'english': 'Seconds', 'french': 'Secondes', 'display_order': 40},
        {'category': 'numbers', 'kirundi': 'Ni isaha zingahe?', 'english': 'What time is it?', 'french': 'Quelle heure est-il ?', 'display_order': 41},
        # Days
        {'category': 'numbers', 'kirundi': 'Ku wa mbere', 'english': 'Monday', 'french': 'Lundi', 'display_order': 42},
        {'category': 'numbers', 'kirundi': 'Ku wa kabiri', 'english': 'Tuesday', 'french': 'Mardi', 'display_order': 43},
        {'category': 'numbers', 'kirundi': 'Ku wa gatatu', 'english': 'Wednesday', 'french': 'Mercredi', 'display_order': 44},
        {'category': 'numbers', 'kirundi': 'Ku wa kane', 'english': 'Thursday', 'french': 'Jeudi', 'display_order': 45},
        {'category': 'numbers', 'kirundi': 'Ku wa gatanu', 'english': 'Friday', 'french': 'Vendredi', 'display_order': 46},
        {'category': 'numbers', 'kirundi': 'Ku wa gatandatu', 'english': 'Saturday', 'french': 'Samedi', 'display_order': 47},
        {'category': 'numbers', 'kirundi': 'Ku musi w\'Imana', 'english': 'Sunday', 'french': 'Dimanche', 'display_order': 48},
        # Months
        {'category': 'numbers', 'kirundi': 'Nzero', 'english': 'January', 'french': 'Janvier', 'display_order': 49},
        {'category': 'numbers', 'kirundi': 'Ruhuhuma', 'english': 'February', 'french': 'Février', 'display_order': 50},
        {'category': 'numbers', 'kirundi': 'Ntwarante', 'english': 'March', 'french': 'Mars', 'display_order': 51},
        {'category': 'numbers', 'kirundi': 'Ndamukiza', 'english': 'April', 'french': 'Avril', 'display_order': 52},
        {'category': 'numbers', 'kirundi': 'Rusama', 'english': 'May', 'french': 'Mai', 'display_order': 53},
        {'category': 'numbers', 'kirundi': 'Ruheshi', 'english': 'June', 'french': 'Juin', 'display_order': 54},
        {'category': 'numbers', 'kirundi': 'Mukakaro', 'english': 'July', 'french': 'Juillet', 'display_order': 55},
        {'category': 'numbers', 'kirundi': 'Myandagaro', 'english': 'August', 'french': 'Août', 'display_order': 56},
        {'category': 'numbers', 'kirundi': 'Nyakanga', 'english': 'September', 'french': 'Septembre', 'display_order': 57},
        {'category': 'numbers', 'kirundi': 'Gitugutu', 'english': 'October', 'french': 'Octobre', 'display_order': 58},
        {'category': 'numbers', 'kirundi': 'Munyonyo', 'english': 'November', 'french': 'Novembre', 'display_order': 59},
        {'category': 'numbers', 'kirundi': 'Kigarama', 'english': 'December', 'french': 'Décembre', 'display_order': 60},
        # Time concepts
        {'category': 'numbers', 'kirundi': 'Uyu musi', 'english': 'Today', 'french': 'Aujourd\'hui', 'display_order': 61},
        {'category': 'numbers', 'kirundi': 'Ejo', 'english': 'Yesterday / Tomorrow', 'french': 'Hier / Demain', 'display_order': 62},
        {'category': 'numbers', 'kirundi': 'Ejo bundi', 'english': 'Day before yesterday / Day after tomorrow', 'french': 'Avant-hier / Après-demain', 'display_order': 63},
        {'category': 'numbers', 'kirundi': 'Indwi', 'english': 'Week', 'french': 'Semaine', 'display_order': 64},
        {'category': 'numbers', 'kirundi': 'Ukwezi', 'english': 'Month', 'french': 'Mois', 'display_order': 65},
        {'category': 'numbers', 'kirundi': 'Umwaka', 'english': 'Year', 'french': 'Année', 'display_order': 66},

        # ══════════════════════════════════════════════════════════════
        #  FOOD & DRINK  (continuing from display_order 15+)
        # ══════════════════════════════════════════════════════════════
        {'category': 'food', 'kirundi': 'Ubuyi', 'english': 'Peanuts / Groundnuts', 'french': 'Arachides / Cacahuètes', 'display_order': 15},
        {'category': 'food', 'kirundi': 'Imyumbati', 'english': 'Cassava', 'french': 'Manioc', 'display_order': 16},
        {'category': 'food', 'kirundi': 'Ibigori', 'english': 'Corn / Maize', 'french': 'Maïs', 'display_order': 17},
        {'category': 'food', 'kirundi': 'Imboga', 'english': 'Vegetables', 'french': 'Légumes', 'display_order': 18},
        {'category': 'food', 'kirundi': 'Ivyamwa', 'english': 'Fruits', 'french': 'Fruits', 'display_order': 19},
        {'category': 'food', 'kirundi': 'Umuneke', 'english': 'Banana (cooking)', 'french': 'Banane plantain', 'display_order': 20},
        {'category': 'food', 'kirundi': 'Inanasi', 'english': 'Pineapple', 'french': 'Ananas', 'display_order': 21},
        {'category': 'food', 'kirundi': 'Imyembe', 'english': 'Mangoes', 'french': 'Mangues', 'display_order': 22},
        {'category': 'food', 'kirundi': 'Ipapaya', 'english': 'Papaya', 'french': 'Papaye', 'display_order': 23},
        {'category': 'food', 'kirundi': 'Avoka', 'english': 'Avocado', 'french': 'Avocat', 'display_order': 24},
        {'category': 'food', 'kirundi': 'Umutobe', 'english': 'Juice', 'french': 'Jus', 'display_order': 25},
        {'category': 'food', 'kirundi': 'Inzoga', 'english': 'Beer / Alcoholic drink', 'french': 'Bière / Boisson alcoolisée', 'display_order': 26},
        {'category': 'food', 'kirundi': 'Urwarwa', 'english': 'Banana beer (traditional)', 'french': 'Bière de banane (traditionnelle)', 'display_order': 27},
        {'category': 'food', 'kirundi': 'Impeke', 'english': 'Sorghum beer', 'french': 'Bière de sorgho', 'display_order': 28},
        {'category': 'food', 'kirundi': 'Amata', 'english': 'Milk', 'french': 'Lait', 'display_order': 29},
        {'category': 'food', 'kirundi': 'Ikivuguto', 'english': 'Yogurt / Fermented milk', 'french': 'Yaourt / Lait fermenté', 'display_order': 30},
        {'category': 'food', 'kirundi': 'Igikoma', 'english': 'Porridge', 'french': 'Bouillie', 'display_order': 31},
        {'category': 'food', 'kirundi': 'Ubugari', 'english': 'Ugali (cassava paste)', 'french': 'Pâte de manioc', 'display_order': 32},
        {'category': 'food', 'kirundi': 'Isombe', 'english': 'Cassava leaves', 'french': 'Feuilles de manioc', 'display_order': 33},
        {'category': 'food', 'kirundi': 'Inyama y\'inkoko', 'english': 'Chicken', 'french': 'Poulet', 'display_order': 34},
        {'category': 'food', 'kirundi': 'Inyama y\'ihene', 'english': 'Goat meat', 'french': 'Viande de chèvre', 'display_order': 35},
        {'category': 'food', 'kirundi': 'Inyama y\'inka', 'english': 'Beef', 'french': 'Viande de bœuf', 'display_order': 36},
        {'category': 'food', 'kirundi': 'Indagara', 'english': 'Tilapia (Lake Tanganyika fish)', 'french': 'Tilapia (poisson du lac Tanganyika)', 'display_order': 37},
        {'category': 'food', 'kirundi': 'Sangala', 'english': 'Nile perch', 'french': 'Perche du Nil', 'display_order': 38},
        {'category': 'food', 'kirundi': 'Amagi', 'english': 'Eggs', 'french': 'Œufs', 'display_order': 39},
        {'category': 'food', 'kirundi': 'Umukate', 'english': 'Bread', 'french': 'Pain', 'display_order': 40},
        {'category': 'food', 'kirundi': 'Umunyu', 'english': 'Salt', 'french': 'Sel', 'display_order': 41},
        {'category': 'food', 'kirundi': 'Isukari', 'english': 'Sugar', 'french': 'Sucre', 'display_order': 42},
        {'category': 'food', 'kirundi': 'Ipilipili', 'english': 'Pepper / Chili', 'french': 'Piment / Poivre', 'display_order': 43},
        {'category': 'food', 'kirundi': 'Amavuta', 'english': 'Oil / Butter', 'french': 'Huile / Beurre', 'display_order': 44},
        {'category': 'food', 'kirundi': 'Ndashaka ifunguro', 'english': 'I would like a meal', 'french': 'Je voudrais un repas', 'display_order': 45},
        {'category': 'food', 'kirundi': 'Menu ni iyihe?', 'english': 'What is on the menu?', 'french': 'Quel est le menu ?', 'display_order': 46},
        {'category': 'food', 'kirundi': 'Ni biryoheye cane', 'english': 'It is delicious', 'french': 'C\'est délicieux', 'display_order': 47},
        {'category': 'food', 'kirundi': 'Ndashaka amazi meza', 'english': 'I want clean/bottled water', 'french': 'Je veux de l\'eau propre/en bouteille', 'display_order': 48},
        {'category': 'food', 'kirundi': 'Facture, n\'agahore', 'english': 'The bill, please', 'french': 'L\'addition, s\'il vous plaît', 'display_order': 49},
        {'category': 'food', 'kirundi': 'Ntabwo ndya inyama', 'english': 'I don\'t eat meat', 'french': 'Je ne mange pas de viande', 'display_order': 50},
        {'category': 'food', 'kirundi': 'Ndafise aleriji', 'english': 'I have an allergy', 'french': 'J\'ai une allergie', 'display_order': 51},
        {'category': 'food', 'kirundi': 'Igikombe c\'icayi', 'english': 'A cup of tea', 'french': 'Une tasse de thé', 'display_order': 52},
        {'category': 'food', 'kirundi': 'Igikombe c\'ikawa', 'english': 'A cup of coffee', 'french': 'Une tasse de café', 'display_order': 53},
        {'category': 'food', 'kirundi': 'Soda', 'english': 'Soft drink / Soda', 'french': 'Boisson gazeuse / Soda', 'display_order': 54},
        {'category': 'food', 'kirundi': 'Ibinyobwa', 'english': 'Drinks / Beverages', 'french': 'Boissons', 'display_order': 55},

        # ══════════════════════════════════════════════════════════════
        #  TRAVEL  (continuing from display_order 11+)
        # ══════════════════════════════════════════════════════════════
        {'category': 'travel', 'kirundi': 'Igitikisi', 'english': 'Taxi', 'french': 'Taxi', 'display_order': 11},
        {'category': 'travel', 'kirundi': 'Igare', 'english': 'Bus station / Train station', 'french': 'Gare routière / Gare', 'display_order': 12},
        {'category': 'travel', 'kirundi': 'Igiceri c\'urugendo', 'english': 'Ticket / Fare', 'french': 'Billet / Tarif', 'display_order': 13},
        {'category': 'travel', 'kirundi': 'Iviza', 'english': 'Visa', 'french': 'Visa', 'display_order': 14},
        {'category': 'travel', 'kirundi': 'Iduwane', 'english': 'Customs', 'french': 'Douane', 'display_order': 15},
        {'category': 'travel', 'kirundi': 'Urubibe', 'english': 'Border', 'french': 'Frontière', 'display_order': 16},
        {'category': 'travel', 'kirundi': 'Aho bapimira', 'english': 'Checkpoint', 'french': 'Point de contrôle', 'display_order': 17},
        {'category': 'travel', 'kirundi': 'Amavalizi', 'english': 'Luggage / Baggage', 'french': 'Bagages', 'display_order': 18},
        {'category': 'travel', 'kirundi': 'Isakoshi', 'english': 'Suitcase / Bag', 'french': 'Valise / Sac', 'display_order': 19},
        {'category': 'travel', 'kirundi': 'Ikaye', 'english': 'Bag / Backpack', 'french': 'Sac / Sac à dos', 'display_order': 20},
        {'category': 'travel', 'kirundi': 'Bujumbura', 'english': 'Bujumbura (economic capital)', 'french': 'Bujumbura (capitale économique)', 'display_order': 21},
        {'category': 'travel', 'kirundi': 'Gitega', 'english': 'Gitega (political capital)', 'french': 'Gitega (capitale politique)', 'display_order': 22},
        {'category': 'travel', 'kirundi': 'Ikiyaga ca Tanganyika', 'english': 'Lake Tanganyika', 'french': 'Lac Tanganyika', 'display_order': 23},
        {'category': 'travel', 'kirundi': 'Uruzi Rusizi', 'english': 'Rusizi River', 'french': 'Rivière Rusizi', 'display_order': 24},
        {'category': 'travel', 'kirundi': 'Parike ya Ruvubu', 'english': 'Ruvubu National Park', 'french': 'Parc National de la Ruvubu', 'display_order': 25},
        {'category': 'travel', 'kirundi': 'Parike ya Kibira', 'english': 'Kibira National Park', 'french': 'Parc National de la Kibira', 'display_order': 26},
        {'category': 'travel', 'kirundi': 'Isoko y\'umuzi wa Nili', 'english': 'Source of the Nile', 'french': 'Source du Nil', 'display_order': 27},
        {'category': 'travel', 'kirundi': 'Ndashaka icumba', 'english': 'I need a room', 'french': 'J\'ai besoin d\'une chambre', 'display_order': 28},
        {'category': 'travel', 'kirundi': 'Icumba kirugahe ku musi?', 'english': 'How much is a room per night?', 'french': 'Combien coûte une chambre par nuit ?', 'display_order': 29},
        {'category': 'travel', 'kirundi': 'Ndashaka kwiyandikisha', 'english': 'I want to check in', 'french': 'Je veux m\'enregistrer', 'display_order': 30},
        {'category': 'travel', 'kirundi': 'Ndashaka gusohoka', 'english': 'I want to check out', 'french': 'Je veux régler la note', 'display_order': 31},
        {'category': 'travel', 'kirundi': 'WiFi ni iyihe?', 'english': 'What is the WiFi password?', 'french': 'Quel est le mot de passe WiFi ?', 'display_order': 32},
        {'category': 'travel', 'kirundi': 'Ndashaka guhindura amadolari', 'english': 'I want to exchange dollars', 'french': 'Je veux changer des dollars', 'display_order': 33},
        {'category': 'travel', 'kirundi': 'Ifaranga ry\'Uburundi', 'english': 'Burundian franc (BIF)', 'french': 'Franc burundais (BIF)', 'display_order': 34},
        {'category': 'travel', 'kirundi': 'Ndashaka SIM karato', 'english': 'I need a SIM card', 'french': 'J\'ai besoin d\'une carte SIM', 'display_order': 35},
        {'category': 'travel', 'kirundi': 'Telefone yanje yavuyemwo umuyagankuba', 'english': 'My phone battery is dead', 'french': 'La batterie de mon téléphone est morte', 'display_order': 36},
        {'category': 'travel', 'kirundi': 'Ni hehe aho bacaja umuyagankuba?', 'english': 'Where can I charge my phone?', 'french': 'Où puis-je charger mon téléphone ?', 'display_order': 37},
        {'category': 'travel', 'kirundi': 'Ndafise ikibazo', 'english': 'I have a problem', 'french': 'J\'ai un problème', 'display_order': 38},
        {'category': 'travel', 'kirundi': 'Ntabifashije', 'english': 'Help me!', 'french': 'Aidez-moi !', 'display_order': 39},
        {'category': 'travel', 'kirundi': 'Hamagara polisi', 'english': 'Call the police', 'french': 'Appelez la police', 'display_order': 40},
        {'category': 'travel', 'kirundi': 'Hamagara amburansi', 'english': 'Call an ambulance', 'french': 'Appelez une ambulance', 'display_order': 41},
        {'category': 'travel', 'kirundi': 'Ndwaye', 'english': 'I am sick', 'french': 'Je suis malade', 'display_order': 42},
        {'category': 'travel', 'kirundi': 'Ni hehe aho babona umuganga?', 'english': 'Where can I see a doctor?', 'french': 'Où puis-je voir un médecin ?', 'display_order': 43},
        {'category': 'travel', 'kirundi': 'Umuganga', 'english': 'Doctor', 'french': 'Médecin', 'display_order': 44},
        {'category': 'travel', 'kirundi': 'Ibitaro', 'english': 'Hospital', 'french': 'Hôpital', 'display_order': 45},
        {'category': 'travel', 'kirundi': 'Ifarumasi', 'english': 'Pharmacy', 'french': 'Pharmacie', 'display_order': 46},
        {'category': 'travel', 'kirundi': 'Imiti', 'english': 'Medicine', 'french': 'Médicaments', 'display_order': 47},
        {'category': 'travel', 'kirundi': 'Ndashaka kugerageza', 'english': 'I want to try', 'french': 'Je veux essayer', 'display_order': 48},
        {'category': 'travel', 'kirundi': 'Ni safe?', 'english': 'Is it safe?', 'french': 'C\'est sûr ?', 'display_order': 49},
        {'category': 'travel', 'kirundi': 'Ikibanza co gushirukira', 'english': 'Meeting point', 'french': 'Point de rencontre', 'display_order': 50},

        # ══════════════════════════════════════════════════════════════
        #  CULTURE  (continuing from display_order 10+)
        # ══════════════════════════════════════════════════════════════
        {'category': 'culture', 'kirundi': 'Ikirundi', 'english': 'Kirundi language', 'french': 'Langue kirundi', 'display_order': 10},
        {'category': 'culture', 'kirundi': 'Igisoro', 'english': 'Mancala (traditional board game)', 'french': 'Mancala (jeu de société traditionnel)', 'display_order': 11},
        {'category': 'culture', 'kirundi': 'Imigani', 'english': 'Proverbs / Riddles', 'french': 'Proverbes / Devinettes', 'display_order': 12},
        {'category': 'culture', 'kirundi': 'Amazina y\'ikirundi', 'english': 'Kirundi names (have meanings)', 'french': 'Noms kirundi (ont des significations)', 'display_order': 13},
        {'category': 'culture', 'kirundi': 'Ikivi', 'english': 'Traditional cloth / Fabric', 'french': 'Tissu / Étoffe traditionnelle', 'display_order': 14},
        {'category': 'culture', 'kirundi': 'Impuzu', 'english': 'Clothing', 'french': 'Vêtements', 'display_order': 15},
        {'category': 'culture', 'kirundi': 'Ubuhamya', 'english': 'Testimony / Heritage', 'french': 'Témoignage / Patrimoine', 'display_order': 16},
        {'category': 'culture', 'kirundi': 'Inanga', 'english': 'Traditional zither instrument', 'french': 'Cithare traditionnelle', 'display_order': 17},
        {'category': 'culture', 'kirundi': 'Ikidumbadumba', 'english': 'Large ceremonial drum', 'french': 'Grand tambour cérémonial', 'display_order': 18},
        {'category': 'culture', 'kirundi': 'Umuvyimba', 'english': 'Flute (traditional)', 'french': 'Flûte (traditionnelle)', 'display_order': 19},
        {'category': 'culture', 'kirundi': 'Umuziki', 'english': 'Music', 'french': 'Musique', 'display_order': 20},
        {'category': 'culture', 'kirundi': 'Igitaramo', 'english': 'Festival / Celebration', 'french': 'Festival / Célébration', 'display_order': 21},
        {'category': 'culture', 'kirundi': 'Ubukwe', 'english': 'Wedding', 'french': 'Mariage', 'display_order': 22},
        {'category': 'culture', 'kirundi': 'Gusaba', 'english': 'Traditional marriage proposal', 'french': 'Demande en mariage traditionnelle', 'display_order': 23},
        {'category': 'culture', 'kirundi': 'Gukwa', 'english': 'Dowry / Bride price ceremony', 'french': 'Dot / Cérémonie de la dot', 'display_order': 24},
        {'category': 'culture', 'kirundi': 'Indero', 'english': 'Education / Upbringing', 'french': 'Éducation / Formation', 'display_order': 25},
        {'category': 'culture', 'kirundi': 'Umuryango', 'english': 'Family / Clan', 'french': 'Famille / Clan', 'display_order': 26},
        {'category': 'culture', 'kirundi': 'Umuhana', 'english': 'Communal farming help', 'french': 'Entraide agricole communale', 'display_order': 27},
        {'category': 'culture', 'kirundi': 'Ubushingantahe', 'english': 'Council of elders / Wise men', 'french': 'Conseil des sages', 'display_order': 28},
        {'category': 'culture', 'kirundi': 'Bashingantahe', 'english': 'Elders (judges of integrity)', 'french': 'Sages (juges d\'intégrité)', 'display_order': 29},
        {'category': 'culture', 'kirundi': 'Imvugo', 'english': 'Speech / Oratory', 'french': 'Discours / Art oratoire', 'display_order': 30},
        {'category': 'culture', 'kirundi': 'Ivyibutso', 'english': 'Memorial / Monument', 'french': 'Mémorial / Monument', 'display_order': 31},
        {'category': 'culture', 'kirundi': 'Akaranga', 'english': 'Cultural heritage / Tradition', 'french': 'Patrimoine culturel / Tradition', 'display_order': 32},
        {'category': 'culture', 'kirundi': 'Igihugu c\'amahoro', 'english': 'Country of peace', 'french': 'Pays de paix', 'display_order': 33},
        {'category': 'culture', 'kirundi': 'Indimiro', 'english': 'Farm / Field', 'french': 'Ferme / Champ', 'display_order': 34},
        {'category': 'culture', 'kirundi': 'Uburezi', 'english': 'Education system', 'french': 'Système éducatif', 'display_order': 35},
        {'category': 'culture', 'kirundi': 'Ivyegera', 'english': 'Arts / Crafts', 'french': 'Arts / Artisanat', 'display_order': 36},
        {'category': 'culture', 'kirundi': 'Igitabo', 'english': 'Book', 'french': 'Livre', 'display_order': 37},
        {'category': 'culture', 'kirundi': 'Ishure', 'english': 'School', 'french': 'École', 'display_order': 38},
        {'category': 'culture', 'kirundi': 'Kaminuza', 'english': 'University', 'french': 'Université', 'display_order': 39},
        {'category': 'culture', 'kirundi': 'Insiguro', 'english': 'Explanation / Meaning', 'french': 'Explication / Signification', 'display_order': 40},
        {'category': 'culture', 'kirundi': 'Ikirundigihe', 'english': 'Storytelling time', 'french': 'Temps de contes', 'display_order': 41},
        {'category': 'culture', 'kirundi': 'Umugani', 'english': 'Proverb / Saying', 'french': 'Proverbe / Dicton', 'display_order': 42},
        {'category': 'culture', 'kirundi': 'Akanyamuneza', 'english': 'Joy / Happiness', 'french': 'Joie / Bonheur', 'display_order': 43},
        {'category': 'culture', 'kirundi': 'Iteka', 'english': 'Dignity / Honor', 'french': 'Dignité / Honneur', 'display_order': 44},
        {'category': 'culture', 'kirundi': 'Urupfu rw\'ubwenge', 'english': 'Wisdom', 'french': 'Sagesse', 'display_order': 45},
        {'category': 'culture', 'kirundi': 'Urukundo', 'english': 'Love', 'french': 'Amour', 'display_order': 46},
        {'category': 'culture', 'kirundi': 'Ubutwari', 'english': 'Courage / Bravery', 'french': 'Courage / Bravoure', 'display_order': 47},

        # ══════════════════════════════════════════════════════════════
        #  BUSINESS  (continuing from display_order 11+)
        # ══════════════════════════════════════════════════════════════
        {'category': 'business', 'kirundi': 'Ubucuruzi', 'english': 'Commerce / Trade', 'french': 'Commerce', 'display_order': 11},
        {'category': 'business', 'kirundi': 'Umucuruzi', 'english': 'Merchant / Trader', 'french': 'Commerçant', 'display_order': 12},
        {'category': 'business', 'kirundi': 'Isoko mpuzamakungu', 'english': 'International market', 'french': 'Marché international', 'display_order': 13},
        {'category': 'business', 'kirundi': 'Igiciro', 'english': 'Price', 'french': 'Prix', 'display_order': 14},
        {'category': 'business', 'kirundi': 'Ni birahenda', 'english': 'It is expensive', 'french': 'C\'est cher', 'display_order': 15},
        {'category': 'business', 'kirundi': 'Ni bikenewe', 'english': 'It is cheap / affordable', 'french': 'C\'est bon marché / abordable', 'display_order': 16},
        {'category': 'business', 'kirundi': 'Gukura igiciro', 'english': 'To negotiate / Bargain', 'french': 'Négocier / Marchander', 'display_order': 17},
        {'category': 'business', 'kirundi': 'Ushobora kugabanya igiciro?', 'english': 'Can you reduce the price?', 'french': 'Pouvez-vous baisser le prix ?', 'display_order': 18},
        {'category': 'business', 'kirundi': 'Igikorwa', 'english': 'Task / Activity', 'french': 'Tâche / Activité', 'display_order': 19},
        {'category': 'business', 'kirundi': 'Umushinga', 'english': 'Project', 'french': 'Projet', 'display_order': 20},
        {'category': 'business', 'kirundi': 'Isosiyete', 'english': 'Company', 'french': 'Société / Entreprise', 'display_order': 21},
        {'category': 'business', 'kirundi': 'Umuyobozi mukuru', 'english': 'CEO / Managing Director', 'french': 'PDG / Directeur général', 'display_order': 22},
        {'category': 'business', 'kirundi': 'Uburinganire', 'english': 'Equality / Equity', 'french': 'Égalité / Équité', 'display_order': 23},
        {'category': 'business', 'kirundi': 'Ibikorwa', 'english': 'Activities / Operations', 'french': 'Activités / Opérations', 'display_order': 24},
        {'category': 'business', 'kirundi': 'Gushinga', 'english': 'To invest', 'french': 'Investir', 'display_order': 25},
        {'category': 'business', 'kirundi': 'Igishinga', 'english': 'Investment', 'french': 'Investissement', 'display_order': 26},
        {'category': 'business', 'kirundi': 'Ibikoresho', 'english': 'Equipment / Tools', 'french': 'Équipement / Outils', 'display_order': 27},
        {'category': 'business', 'kirundi': 'Gufatanya', 'english': 'Partnership', 'french': 'Partenariat', 'display_order': 28},
        {'category': 'business', 'kirundi': 'Amasezerano y\'akazi', 'english': 'Contract / Work agreement', 'french': 'Contrat / Accord de travail', 'display_order': 29},
        {'category': 'business', 'kirundi': 'Gutanga amakuru', 'english': 'To provide information', 'french': 'Fournir des informations', 'display_order': 30},
        {'category': 'business', 'kirundi': 'Inama y\'akazi', 'english': 'Business meeting', 'french': 'Réunion d\'affaires', 'display_order': 31},
        {'category': 'business', 'kirundi': 'Amahera', 'english': 'Cash / Currency', 'french': 'Espèces / Monnaie', 'display_order': 32},
        {'category': 'business', 'kirundi': 'Kwishura', 'english': 'To pay', 'french': 'Payer', 'display_order': 33},
        {'category': 'business', 'kirundi': 'Ikibanza co kwishura', 'english': 'Payment method', 'french': 'Mode de paiement', 'display_order': 34},
        {'category': 'business', 'kirundi': 'Mobile money', 'english': 'Mobile money (Lumicash, Ecocash)', 'french': 'Mobile money (Lumicash, Ecocash)', 'display_order': 35},
        {'category': 'business', 'kirundi': 'Imfashanyo', 'english': 'Aid / Assistance', 'french': 'Aide / Assistance', 'display_order': 36},
        {'category': 'business', 'kirundi': 'Impuha', 'english': 'Tax / Duty', 'french': 'Impôt / Taxe', 'display_order': 37},
        {'category': 'business', 'kirundi': 'Gutumiza ibintu', 'english': 'To import goods', 'french': 'Importer des marchandises', 'display_order': 38},
        {'category': 'business', 'kirundi': 'Kohereza ibintu', 'english': 'To export goods', 'french': 'Exporter des marchandises', 'display_order': 39},
        {'category': 'business', 'kirundi': 'Igikorwa co guteza imbere', 'english': 'Development project', 'french': 'Projet de développement', 'display_order': 40},
        {'category': 'business', 'kirundi': 'Ubuhinga bwa none', 'english': 'Technology / Innovation', 'french': 'Technologie / Innovation', 'display_order': 41},
        {'category': 'business', 'kirundi': 'Inshingano', 'english': 'Responsibility / Mandate', 'french': 'Responsabilité / Mandat', 'display_order': 42},
        {'category': 'business', 'kirundi': 'Inyandiko', 'english': 'Document / Certificate', 'french': 'Document / Certificat', 'display_order': 43},
        {'category': 'business', 'kirundi': 'Umukono', 'english': 'Signature', 'french': 'Signature', 'display_order': 44},
        {'category': 'business', 'kirundi': 'Ndashaka gusinyisha', 'english': 'I want to sign', 'french': 'Je veux signer', 'display_order': 45},
        {'category': 'business', 'kirundi': 'Iresi', 'english': 'Receipt', 'french': 'Reçu', 'display_order': 46},
        {'category': 'business', 'kirundi': 'Kohereza kuri email', 'english': 'Send by email', 'french': 'Envoyer par email', 'display_order': 47},
        {'category': 'business', 'kirundi': 'Itumanaho', 'english': 'Communication', 'french': 'Communication', 'display_order': 48},
        {'category': 'business', 'kirundi': 'Ubukungu', 'english': 'Economy', 'french': 'Économie', 'display_order': 49},
        {'category': 'business', 'kirundi': 'Ubuhinzi', 'english': 'Agriculture / Farming', 'french': 'Agriculture', 'display_order': 50},
        {'category': 'business', 'kirundi': 'Ubworozi', 'english': 'Livestock / Animal husbandry', 'french': 'Élevage', 'display_order': 51},
        {'category': 'business', 'kirundi': 'Inganda', 'english': 'Industry / Factory', 'french': 'Industrie / Usine', 'display_order': 52},
        {'category': 'business', 'kirundi': 'Ikoranabuhanga', 'english': 'Information technology', 'french': 'Technologie de l\'information', 'display_order': 53},
        {'category': 'business', 'kirundi': 'Iterambere ridakumira', 'english': 'Sustainable development', 'french': 'Développement durable', 'display_order': 54},
    ]

    PhrasebookEntry.objects.bulk_create([
        PhrasebookEntry(**entry) for entry in entries
    ])


def reverse_expand(apps, schema_editor):
    PhrasebookEntry = apps.get_model('core', 'PhrasebookEntry')
    # Delete only entries added by this migration (display_order > existing max)
    PhrasebookEntry.objects.filter(
        category='greetings', display_order__gte=15
    ).delete()
    PhrasebookEntry.objects.filter(
        category='directions', display_order__gte=12
    ).delete()
    PhrasebookEntry.objects.filter(
        category='diplomacy', display_order__gte=13
    ).delete()
    PhrasebookEntry.objects.filter(
        category='numbers', display_order__gte=13
    ).delete()
    PhrasebookEntry.objects.filter(
        category='food', display_order__gte=15
    ).delete()
    PhrasebookEntry.objects.filter(
        category='travel', display_order__gte=11
    ).delete()
    PhrasebookEntry.objects.filter(
        category='culture', display_order__gte=10
    ).delete()
    PhrasebookEntry.objects.filter(
        category='business', display_order__gte=11
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0161_seed_phrasebook_entries'),
    ]

    operations = [
        migrations.RunPython(expand_phrasebook, reverse_expand),
    ]
