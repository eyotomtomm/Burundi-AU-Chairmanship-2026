class EmbassyLocation {
  final String id;
  final String name;
  final String nameFr;
  final String address;
  final String city;
  final String country;
  final double latitude;
  final double longitude;
  final String phoneNumber;
  final String email;
  final String website;
  final String openingHours;
  final LocationType type;
  final String imageUrl;

  EmbassyLocation({
    required this.id,
    required this.name,
    required this.nameFr,
    required this.address,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.phoneNumber,
    required this.email,
    required this.website,
    required this.openingHours,
    required this.type,
    required this.imageUrl,
  });

  static LocationType _parseType(String? type) {
    switch (type) {
      case 'embassy': return LocationType.embassy;
      case 'consulate': return LocationType.consulate;
      case 'event_venue': return LocationType.eventVenue;
      case 'office': return LocationType.office;
      default: return LocationType.embassy;
    }
  }

  factory EmbassyLocation.fromJson(Map<String, dynamic> json) {
    return EmbassyLocation(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      nameFr: json['name_fr'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'] ?? '',
      website: json['website'] ?? '',
      openingHours: json['opening_hours'] ?? '',
      type: _parseType(json['type']),
      imageUrl: json['image'] ?? '',
    );
  }

  String getName(String languageCode) => languageCode == 'fr' ? nameFr : name;
}

class EventLocation {
  final String id;
  final String name;
  final String nameFr;
  final String description;
  final String descriptionFr;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime eventDate;
  final String imageUrl;

  EventLocation({
    required this.id,
    required this.name,
    required this.nameFr,
    required this.description,
    required this.descriptionFr,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.eventDate,
    required this.imageUrl,
  });

  factory EventLocation.fromJson(Map<String, dynamic> json) {
    return EventLocation(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      nameFr: json['name_fr'] ?? '',
      description: json['description'] ?? '',
      descriptionFr: json['description_fr'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      eventDate: DateTime.tryParse(json['event_date'] ?? '') ?? DateTime.now(),
      imageUrl: json['image'] ?? '',
    );
  }

  String getName(String languageCode) => languageCode == 'fr' ? nameFr : name;
  String getDescription(String languageCode) => languageCode == 'fr' ? descriptionFr : description;
}

enum LocationType { embassy, consulate, eventVenue, office }

// Mock Data
class LocationData {
  static List<EmbassyLocation> getMockEmbassies() {
    return [
      EmbassyLocation(
        id: '1',
        name: 'Embassy of Burundi - Addis Ababa',
        nameFr: 'Ambassade du Burundi - Addis-Abeba',
        address: 'Kirkos Sub City, Addis Ababa',
        city: 'Addis Ababa',
        country: 'Ethiopia',
        latitude: 9.0054,
        longitude: 38.7636,
        phoneNumber: '+251 11 651 3422',
        email: 'embassy.addis@burundi.gov.bi',
        website: 'https://burundi.gov.bi',
        openingHours: 'Mon-Fri: 8:00 AM - 5:00 PM',
        type: LocationType.embassy,
        imageUrl: 'https://via.placeholder.com/400x300/1EB53A/FFFFFF?text=Embassy',
      ),
      EmbassyLocation(
        id: '2',
        name: 'Burundi Consulate - Nairobi',
        nameFr: 'Consulat du Burundi - Nairobi',
        address: 'Development House, Moi Avenue, Nairobi',
        city: 'Nairobi',
        country: 'Kenya',
        latitude: -1.2864,
        longitude: 36.8172,
        phoneNumber: '+254 20 271 8681',
        email: 'consulate.nairobi@burundi.gov.bi',
        website: 'https://burundi.gov.bi',
        openingHours: 'Mon-Fri: 9:00 AM - 4:00 PM',
        type: LocationType.consulate,
        imageUrl: 'https://via.placeholder.com/400x300/CE1126/FFFFFF?text=Consulate',
      ),
      EmbassyLocation(
        id: '3',
        name: 'Embassy of Burundi - Brussels',
        nameFr: 'Ambassade du Burundi - Bruxelles',
        address: 'Square Marie-Louise 46, Brussels',
        city: 'Brussels',
        country: 'Belgium',
        latitude: 50.8479,
        longitude: 4.3740,
        phoneNumber: '+32 2 230 45 35',
        email: 'embassy.brussels@burundi.gov.bi',
        website: 'https://burundi.gov.bi',
        openingHours: 'Mon-Fri: 9:00 AM - 5:00 PM',
        type: LocationType.embassy,
        imageUrl: 'https://via.placeholder.com/400x300/D4AF37/FFFFFF?text=Embassy+Brussels',
      ),
    ];
  }

  static List<EventLocation> getMockEvents() {
    return [
      EventLocation(
        id: '1',
        name: 'AU Summit Main Venue',
        nameFr: 'Lieu principal du Sommet de l\'UA',
        description: 'Main venue for the African Union Summit 2025',
        descriptionFr: 'Lieu principal du Sommet de l\'Union africaine 2025',
        address: 'Bujumbura Convention Center, Burundi',
        latitude: -3.3614,
        longitude: 29.3599,
        eventDate: DateTime(2025, 2, 10),
        imageUrl: 'https://via.placeholder.com/400x300/1EB53A/FFFFFF?text=Summit',
      ),
      EventLocation(
        id: '2',
        name: 'Cultural Exhibition Center',
        nameFr: 'Centre d\'exposition culturelle',
        description: 'Showcasing African art and culture',
        descriptionFr: 'Présentation de l\'art et de la culture africains',
        address: 'National Museum, Bujumbura',
        latitude: -3.3784,
        longitude: 29.3644,
        eventDate: DateTime(2025, 2, 11),
        imageUrl: 'https://via.placeholder.com/400x300/CE1126/FFFFFF?text=Culture',
      ),
      EventLocation(
        id: '3',
        name: 'Economic Forum Hall',
        nameFr: 'Salle du Forum économique',
        description: 'Business and economic discussions',
        descriptionFr: 'Discussions commerciales et économiques',
        address: 'Trade Center, Bujumbura',
        latitude: -3.3734,
        longitude: 29.3544,
        eventDate: DateTime(2025, 2, 12),
        imageUrl: 'https://via.placeholder.com/400x300/D4AF37/FFFFFF?text=Forum',
      ),
    ];
  }
}
