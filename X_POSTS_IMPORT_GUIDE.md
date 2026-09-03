# @BurundinAddis X Posts Import Guide

Content extracted from [https://x.com/BurundinAddis](https://x.com/BurundinAddis) (Jan 2025 - May 2026).
Images downloaded to: `burundi_au_chairmanship/backend/media/x_imports/`

---

## How to Use This Guide

Each post below is categorized into where it should go in the backend:
- **ARTICLE** — News/diplomatic updates (goes into Articles section)
- **EVENT** — Past events with a date/location (goes into Events section)
- **LIVEFEED** — AU Chairmanship highlights (goes into Live Feeds section)

After running `python manage.py import_x_posts`, use the admin panel to:
1. Upload the corresponding image(s) listed for each entry
2. For Events: create them manually using the info below (events require lat/lng)

---

## 1. Ghana AU Commissioner Courtesy Call

| Field | Value |
|-------|-------|
| **Category** | ARTICLE (Diplomacy) |
| **Date** | January 28, 2025 |
| **X Post** | [Link](https://x.com/BurundinAddis/status/1884308412479201379) |

**Title (EN):** Ghana's AU Commissioner Candidate Pays Courtesy Call on Burundi Ambassador
**Title (FR):** La candidate du Ghana au poste de Commissaire de l'UA rend visite a l'Ambassadeur du Burundi

**Content (EN):**
> Amb. Amma Adomaa Twum-Amoah, Ghana's candidate for AU Commissioner for Health, Humanitarian Affairs & Social Development, paid a courtesy call on Burundi's Amb. Willy Nyamitwe. She shared with him her vision: 'To contribute to Africa's transformation by leading strategic health and social development initiatives.'

**Content (FR):**
> L'Amb. Amma Adomaa Twum-Amoah, candidate du Ghana au poste de Commissaire de l'UA pour la Sante, les Affaires humanitaires et le Developpement social, a rendu une visite de courtoisie a l'Amb. du Burundi Willy Nyamitwe.

**Image to upload:**
- `01_2025-01-28_ghana_commissioner.jpg` (225KB)

---

## 2. Visit to Grand Ethiopian Renaissance Dam (GERD)

| Field | Value |
|-------|-------|
| **Category** | EVENT (Diplomacy) + ARTICLE |
| **Date** | February 23, 2025 |
| **Location** | Grand Ethiopian Renaissance Dam, Ethiopia-Sudan border |
| **X Post** | [Link](https://x.com/BurundinAddis/status/1893603586564620666) |

**Title (EN):** Burundi Ambassador Visits Grand Ethiopian Renaissance Dam
**Title (FR):** L'Ambassadeur du Burundi visite le Grand Barrage de la Renaissance ethiopienne

**Content (EN):**
> Burundi Ambassador @willynyamitwe together with Ministers, Diplomats and Journalists of the Nile Basin Initiative countries (NBI) visited the Grand Ethiopian Renaissance Dam (GERD), at the border between Ethiopia & Sudan, a day after the NileDay2025 commemoration.

**Content (FR):**
> L'Ambassadeur du Burundi @willynyamitwe, accompagne de ministres, diplomates et journalistes des pays de l'Initiative du Bassin du Nil (IBN), a visite le Grand Barrage de la Renaissance ethiopienne (GERD), a la frontiere entre l'Ethiopie et le Soudan.

**For Event creation:**
- Address: Grand Ethiopian Renaissance Dam, Benishangul-Gumuz, Ethiopia
- Latitude: 11.2153
- Longitude: 35.0932

**Images to upload (pick best 1 for article, all 4 available):**
- `02_2025-02-23_gerd_visit_1.jpg` (312KB)
- `02_2025-02-23_gerd_visit_2.jpg` (271KB)
- `02_2025-02-23_gerd_visit_3.jpg` (246KB)
- `02_2025-02-23_gerd_visit_4.jpg` (188KB)

---

## 3. Burundi & Equatorial Guinea Bilateral Meeting

| Field | Value |
|-------|-------|
| **Category** | ARTICLE (Diplomacy) |
| **Date** | May 6, 2025 |
| **X Post** | [Link](https://x.com/BurundinAddis/status/1919743416893583534) |

**Title (EN):** Burundi and Equatorial Guinea Ambassadors Discuss Regional Cooperation
**Title (FR):** Les Ambassadeurs du Burundi et de la Guinee equatoriale discutent de la cooperation regionale

**Content (EN):**
> Burundi's Ambassador in Addis Ababa H.E. @willynyamitwe had the pleasure of welcoming his brother and colleague from Equatorial Guinea H.E. @EvunaNtutumu. Both Ambassadors explored ways to further strengthen regional and continental cooperation.

**Content (FR):**
> L'Ambassadeur du Burundi a Addis-Abeba, S.E. @willynyamitwe, a eu le plaisir d'accueillir son frere et collegue de Guinee equatoriale, S.E. @EvunaNtutumu. Les deux Ambassadeurs ont explore les moyens de renforcer davantage la cooperation regionale et continentale.

**Image to upload:**
- `03_2025-05-06_equatorial_guinea.jpg` (222KB)

---

## 4. Burundians in Ethiopia Vote in Parliamentary Elections

| Field | Value |
|-------|-------|
| **Category** | EVENT (Governance) + ARTICLE |
| **Date** | June 5, 2025 |
| **Location** | Embassy of Burundi, Addis Ababa, Ethiopia |
| **X Post** | [Link](https://x.com/BurundinAddis/status/1930515336740102283) |

**Title (EN):** Burundians in Ethiopia Vote in Parliamentary Elections
**Title (FR):** Les Burundais en Ethiopie votent aux elections legislatives

**Content (EN):**
> Burundians living in Ethiopia are also taking part in this important civic duty. The Embassy of Burundi has established a dedicated polling station to facilitate their participation.

**Content (FR):**
> Les Burundais vivant en Ethiopie participent egalement a ce devoir civique important. L'Ambassade du Burundi a mis en place un bureau de vote dedie pour faciliter leur participation.

**For Event creation:**
- Address: Embassy of Burundi, Kirkos Sub City, Addis Ababa, Ethiopia
- Latitude: 9.0107
- Longitude: 38.7612

**Images to upload:**
- `04_2025-06-05_voting_1.jpg` (135KB)
- `04_2025-06-05_voting_2.jpg` (188KB)

---

## 5. New Prime Minister and Cabinet Appointed

| Field | Value |
|-------|-------|
| **Category** | ARTICLE (Governance) - MAJOR NEWS |
| **Date** | August 5, 2025 |
| **X Post** | [Link](https://x.com/BurundinAddis/status/1953029128472424772) |

**Title (EN):** New Prime Minister Ntahontuye Appointed, New Cabinet Sworn In
**Title (FR):** Le nouveau Premier Ministre Ntahontuye nomme, nouveau gouvernement investi

**Content (EN):**
> The Embassy of Burundi in Addis Ababa has the honor to inform that H.E. Mr. Nestor Ntahontuye has been appointed Prime Minister and that a new Cabinet of 13 Ministers was sworn in today. H.E. Amb. Edouard Bizimana (@Edbiziman) is the new Minister of Foreign Affairs.

**Content (FR):**
> L'Ambassade du Burundi a Addis-Abeba a l'honneur d'informer que S.E. M. Nestor Ntahontuye a ete nomme Premier Ministre et qu'un nouveau gouvernement de 13 ministres a prete serment aujourd'hui. S.E. Amb. Edouard Bizimana (@Edbiziman) est le nouveau Ministre des Affaires etrangeres.

**Images to upload (pick best 1, all 4 available):**
- `05_2025-08-05_new_pm_1.jpg` (222KB)
- `05_2025-08-05_new_pm_2.jpg` (70KB)
- `05_2025-08-05_new_pm_3.jpg` (105KB)
- `05_2025-08-05_new_pm_4.jpg` (106KB)

---

## 6. Burundi Condemns M23 Vandalism Against Consulate

| Field | Value |
|-------|-------|
| **Category** | ARTICLE (Diplomacy) |
| **Date** | August 17, 2025 |
| **X Post** | [Link](https://x.com/BurundinAddis/status/1956954025292657045) |

**Title (EN):** Burundi Condemns M23 Vandalism Against Consulate in Bukavu
**Title (FR):** Le Burundi condamne le vandalisme du M23 contre le consulat a Bukavu

**Content (EN):**
> Burundi's Minister of Foreign Affairs, H.E. Edouard Bizimana condemned M23's acts of vandalism against Burundi's Consulate in Bukavu, Eastern DRC, stressing that 'such actions constitute a blatant violation of international, diplomatic and consular law.'

**Content (FR):**
> Le Ministre des Affaires etrangeres du Burundi, S.E. Edouard Bizimana, a condamne les actes de vandalisme du M23 contre le Consulat du Burundi a Bukavu, dans l'Est de la RDC, soulignant que 'de tels actes constituent une violation flagrante du droit international, diplomatique et consulaire.'

**Image to upload:** No media — text-only official statement

---

## 7. Health Ministers Joint Meeting at AU HQ

| Field | Value |
|-------|-------|
| **Category** | EVENT (Health) + ARTICLE |
| **Date** | September 6, 2025 |
| **Location** | African Union Headquarters, Addis Ababa |
| **X Post** | [Link](https://x.com/BurundinAddis/status/1964339918928236853) |

**Title (EN):** Burundi Health Minister at AU Joint Meeting of Health Ministers
**Title (FR):** Le Ministre de la Sante du Burundi a la reunion conjointe des ministres de la Sante de l'UA

**Content (EN):**
> Dr. Lydwine Baradahana, Minister of Public Health of Burundi, took part in the 2nd Joint Meeting of Health Ministers from Africa & the Caribbean, held at the African Union HQ in Addis Ababa on 6 Sept 2025. He was accompanied by Mr. Leonce Kwizera, First Counselor at the Embassy.

**Content (FR):**
> Dr. Lydwine Baradahana, Ministre de la Sante publique du Burundi, a participe a la 2e Reunion conjointe des Ministres de la Sante d'Afrique et des Caraibes, tenue au siege de l'Union africaine a Addis-Abeba le 6 septembre 2025.

**For Event creation:**
- Address: African Union Headquarters, Roosevelt Street, Addis Ababa, Ethiopia
- Latitude: 9.0380
- Longitude: 38.7506

**Images to upload:**
- `07_2025-09-06_health_ministers_1.jpg` (63KB)
- `07_2025-09-06_health_ministers_2.jpg` (65KB)
- `07_2025-09-06_health_ministers_3.jpg` (151KB)

---

## 8. 7th AU-EU Summit in Luanda

| Field | Value |
|-------|-------|
| **Category** | EVENT (Diplomacy) + ARTICLE |
| **Date** | November 23, 2025 |
| **Location** | Luanda, Angola |
| **X Post** | [Link](https://x.com/BurundinAddis/status/1993021030722674767) |

**Title (EN):** Burundi Vice-President at 7th AU-EU Summit in Luanda
**Title (FR):** Le Vice-President du Burundi au 7e Sommet UA-UE a Luanda

**Content (EN):**
> Fruitful sidelines meeting at the 7th AU-EU Summit (AUEU25) in Luanda. Hon. Chief Fortune Charumbira (@PapPresident) engaged with H.E. Prosper Bazombaza, Vice-President of Burundi, on advancing regional integration, youth empowerment, and Agenda2063 goals.

**Content (FR):**
> Rencontre fructueuse en marge du 7e Sommet UA-UE (AUEU25) a Luanda. L'Hon. Chef Fortune Charumbira s'est entretenu avec S.E. Prosper Bazombaza, Vice-President du Burundi, sur l'avancement de l'integration regionale, l'autonomisation des jeunes et les objectifs de l'Agenda 2063.

**For Event creation:**
- Address: Convention Center, Luanda, Angola
- Latitude: -8.8390
- Longitude: 13.2894

**Image to upload:**
- `08_2025-11-23_au_eu_summit.jpg` (178KB)

---

## 9. President Visits Soufflet Malt Ethiopia

| Field | Value |
|-------|-------|
| **Category** | ARTICLE (Economy) |
| **Date** | April 9, 2026 |
| **X Post** | [Link](https://x.com/BurundinAddis/status/2042152972147110180) |

**Title (EN):** President Ndayishimiye Visits Soufflet Malt Ethiopia in Bole Lemi SEZ
**Title (FR):** Le President Ndayishimiye visite Soufflet Malt Ethiopia dans la ZES de Bole Lemi

**Content (EN):**
> H.E. @GeneralNeva, President of Burundi, is visiting Soufflet Malt Ethiopia, subsidiary of InVivo Group within Bole Lemi SEZ, guided by General Manager Mr. Thomas Neveu, who is providing a briefing on the plant's production, technological innovations, and investment landscape.

**Content (FR):**
> S.E. @GeneralNeva, President du Burundi, visite Soufflet Malt Ethiopia, filiale du Groupe InVivo dans la ZES de Bole Lemi, guide par le Directeur general M. Thomas Neveu, qui lui presente la production de l'usine, les innovations technologiques et le paysage d'investissement.

**Image to upload:**
- `09_2026-04-09_soufflet_malt.jpg` (235KB)

---

## 10. President Nominated for 2027 Election

| Field | Value |
|-------|-------|
| **Category** | ARTICLE (Governance) - MAJOR NEWS |
| **Date** | April 26, 2026 |
| **X Post** | [Link](https://x.com/BurundinAddis/status/2048364950985253194) |

**Title (EN):** President Ndayishimiye Nominated as CNDD-FDD Candidate for 2027 Election
**Title (FR):** Le President Ndayishimiye designe candidat du CNDD-FDD pour les elections de 2027

**Content (EN):**
> The Embassy of the Republic of Burundi to Ethiopia warmly congratulates @GeneralNeva, President of the Republic of Burundi, on his nomination as the @CnddFdd candidate for the 2027 presidential election, as decided during the Extraordinary National Congress held on 26 April 2026.

**Content (FR):**
> L'Ambassade de la Republique du Burundi en Ethiopie felicite chaleureusement @GeneralNeva, President de la Republique du Burundi, pour sa nomination comme candidat du @CnddFdd a l'election presidentielle de 2027, decidee lors du Congres National Extraordinaire tenu le 26 avril 2026.

**Images to upload (pick best 1, all 4 available):**
- `10_2026-04-26_2027_nomination_1.jpg` (214KB)
- `10_2026-04-26_2027_nomination_2.jpg` (210KB)
- `10_2026-04-26_2027_nomination_3.jpg` (179KB)
- `10_2026-04-26_2027_nomination_4.jpg` (130KB)

---

## 11. Pan-African Conference on Girls' and Women's Education

| Field | Value |
|-------|-------|
| **Category** | ARTICLE (AU Chairmanship) + LIVEFEED |
| **Date** | May 7, 2026 |
| **X Post** | [Link](https://x.com/BurundinAddis/status/2052379457730629923) |

**Title (EN):** Burundi to Host 2nd AU Pan-African Conference on Girls' and Women's Education
**Title (FR):** Le Burundi accueillera la 2e Conference panafricaine de l'UA sur l'education des filles et des femmes

**Content (EN):**
> Burundi looks forward to hosting the 2nd AU Pan-African Conference on Girls' & Women's in Bujumbura. Under the A-RISE agenda, girls and women's Education stand among the key priorities of Burundi's Chairmanship of the AU.

**Content (FR):**
> Le Burundi se rejouit d'accueillir la 2e Conference panafricaine de l'UA sur les filles et les femmes a Bujumbura. Dans le cadre de l'agenda A-RISE, l'education des filles et des femmes figure parmi les priorites cles de la Presidence du Burundi a l'UA.

**Image to upload:**
- `11_2026-05-07_pan_african_conference.jpg` (150KB)

---

## Summary Table

| # | Date | Title | Backend Section | Has Image |
|---|------|-------|----------------|-----------|
| 1 | Jan 28, 2025 | Ghana AU Commissioner Courtesy Call | Article | Yes (1) |
| 2 | Feb 23, 2025 | GERD Dam Visit | Article + Event | Yes (4) |
| 3 | May 6, 2025 | Equatorial Guinea Bilateral Meeting | Article | Yes (1) |
| 4 | Jun 5, 2025 | Parliamentary Election Voting | Article + Event | Yes (2) |
| 5 | Aug 5, 2025 | New PM & Cabinet Appointed | Article | Yes (4) |
| 6 | Aug 17, 2025 | M23 Consulate Condemnation | Article | No |
| 7 | Sep 6, 2025 | Health Ministers at AU HQ | Article + Event | Yes (3) |
| 8 | Nov 23, 2025 | AU-EU Summit in Luanda | Article + Event | Yes (1) |
| 9 | Apr 9, 2026 | President Visits Factory in Ethiopia | Article | Yes (1) |
| 10 | Apr 26, 2026 | President 2027 Election Nomination | Article | Yes (4) |
| 11 | May 7, 2026 | Pan-African Girls' Education Conf. | Article + LiveFeed | Yes (1) |

---

## Quick Import Steps

1. **Run the management command** to create Articles and LiveFeeds:
   ```bash
   python manage.py import_x_posts --dry-run   # preview first
   python manage.py import_x_posts              # import for real
   ```

2. **Upload images** via admin panel — images are in `backend/media/x_imports/`

3. **Create Events manually** for posts #2, #4, #7, #8 using the location data above
   (Events require latitude/longitude which can't be auto-imported)

4. **Total: 11 articles, 4 events, 1 live feed**
