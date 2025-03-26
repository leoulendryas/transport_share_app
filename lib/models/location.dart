class Location {
  final String name;
  final double lat;
  final double lng;

  Location({
    required this.name,
    required this.lat,
    required this.lng,
  });

  @override
  String toString() => 'Location(name: $name, lat: $lat, lng: $lng)';
}