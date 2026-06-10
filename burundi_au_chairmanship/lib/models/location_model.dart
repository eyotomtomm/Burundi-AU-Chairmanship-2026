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

  String getName(String languageCode) {
    if (languageCode == 'fr') return nameFr.isNotEmpty ? nameFr : name;
    return name.isNotEmpty ? name : nameFr;
  }

  String getDescription(String languageCode) {
    if (languageCode == 'fr') return descriptionFr.isNotEmpty ? descriptionFr : description;
    return description.isNotEmpty ? description : descriptionFr;
  }
}
