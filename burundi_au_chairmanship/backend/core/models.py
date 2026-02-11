from django.db import models


class HeroSlide(models.Model):
    image = models.ImageField(upload_to='hero_slides/')
    label = models.CharField(max_length=100)
    label_fr = models.CharField(max_length=100, blank=True)
    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return self.label


class MagazineEdition(models.Model):
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)
    cover_image = models.ImageField(upload_to='magazines/')
    pdf_file = models.FileField(upload_to='magazines/pdfs/', blank=True)
    publish_date = models.DateField()
    is_featured = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-publish_date']

    def __str__(self):
        return self.title


class Article(models.Model):
    CATEGORY_CHOICES = [
        ('politics', 'Politics'),
        ('economy', 'Economy'),
        ('culture', 'Culture'),
        ('diplomacy', 'Diplomacy'),
    ]

    title = models.CharField(max_length=300)
    title_fr = models.CharField(max_length=300, blank=True)
    content = models.TextField()
    content_fr = models.TextField(blank=True)
    image = models.ImageField(upload_to='articles/', blank=True)
    author = models.CharField(max_length=100)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    publish_date = models.DateTimeField()
    is_featured = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-publish_date']

    def __str__(self):
        return self.title


class EmbassyLocation(models.Model):
    TYPE_CHOICES = [
        ('embassy', 'Embassy'),
        ('consulate', 'Consulate'),
        ('event_venue', 'Event Venue'),
        ('office', 'Office'),
    ]

    name = models.CharField(max_length=200)
    name_fr = models.CharField(max_length=200, blank=True)
    address = models.CharField(max_length=300)
    city = models.CharField(max_length=100)
    country = models.CharField(max_length=100)
    latitude = models.FloatField()
    longitude = models.FloatField()
    phone_number = models.CharField(max_length=50, blank=True)
    email = models.EmailField(blank=True)
    website = models.URLField(blank=True)
    opening_hours = models.CharField(max_length=200, blank=True)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='embassy')
    image = models.ImageField(upload_to='embassies/', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['country', 'city']
        verbose_name_plural = 'Embassy Locations'

    def __str__(self):
        return f"{self.name} - {self.city}, {self.country}"


class Event(models.Model):
    name = models.CharField(max_length=200)
    name_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)
    address = models.CharField(max_length=300)
    latitude = models.FloatField()
    longitude = models.FloatField()
    event_date = models.DateTimeField()
    image = models.ImageField(upload_to='events/', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['event_date']

    def __str__(self):
        return self.name


class LiveFeed(models.Model):
    STATUS_CHOICES = [
        ('live', 'Live'),
        ('upcoming', 'Upcoming'),
        ('recorded', 'Recorded'),
    ]

    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    stream_url = models.URLField()
    thumbnail = models.ImageField(upload_to='live_feeds/', blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='upcoming')
    viewer_count = models.IntegerField(default=0)
    duration = models.CharField(max_length=50, blank=True, help_text='e.g. 1h 30m')
    scheduled_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.get_status_display()}] {self.title}"


class Resource(models.Model):
    CATEGORY_CHOICES = [
        ('official_documents', 'Official Documents'),
        ('country_info', 'Country Information'),
        ('media', 'Media Resources'),
        ('reference', 'Reference Guides'),
    ]
    FILE_TYPE_CHOICES = [
        ('pdf', 'PDF'),
        ('zip', 'ZIP'),
    ]

    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES)
    file = models.FileField(upload_to='resources/')
    file_size = models.CharField(max_length=20, help_text='e.g. 2.4 MB')
    file_type = models.CharField(max_length=10, choices=FILE_TYPE_CHOICES, default='pdf')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['category', 'title']

    def __str__(self):
        return self.title


class EmergencyContact(models.Model):
    TYPE_CHOICES = [
        ('embassy', 'Embassy'),
        ('police', 'Police'),
        ('ambulance', 'Ambulance'),
        ('fire', 'Fire Department'),
    ]

    name = models.CharField(max_length=100)
    name_fr = models.CharField(max_length=100, blank=True)
    phone_number = models.CharField(max_length=50)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return f"{self.name}: {self.phone_number}"


class FeatureCard(models.Model):
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)
    image = models.ImageField(upload_to='feature_cards/', blank=True)
    gradient_start = models.CharField(max_length=10, default='#1EB53A', help_text='Hex color e.g. #1EB53A')
    gradient_end = models.CharField(max_length=10, default='#4CAF50', help_text='Hex color e.g. #4CAF50')
    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return self.title


class AppSettings(models.Model):
    summit_year = models.CharField(max_length=10, default='2026')
    summit_theme = models.CharField(max_length=300)
    summit_theme_fr = models.CharField(max_length=300, blank=True)
    website_url = models.URLField(blank=True)
    facebook_url = models.URLField(blank=True)
    twitter_url = models.URLField(blank=True)
    instagram_url = models.URLField(blank=True)

    class Meta:
        verbose_name = 'App Settings'
        verbose_name_plural = 'App Settings'

    def __str__(self):
        return f"App Settings ({self.summit_year})"
