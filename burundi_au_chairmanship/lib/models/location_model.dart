class EventLocation {
  final String id;
  final String name;
  final String nameFr;
  final String description;
  final String descriptionFr;
  final String address;
  final String mapUrl;
  final DateTime eventDate;
  final String imageUrl;

  EventLocation({
    required this.id,
    required this.name,
    required this.nameFr,
    required this.description,
    required this.descriptionFr,
    required this.address,
    this.mapUrl = '',
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
      mapUrl: json['map_url'] ?? '',
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
