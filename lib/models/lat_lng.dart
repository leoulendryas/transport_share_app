class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);

  Map<String, double> toJson() => {
    'lat': latitude,
    'lng': longitude,
  };
}