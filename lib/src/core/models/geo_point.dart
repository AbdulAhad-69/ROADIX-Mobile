/// Immutable latitude/longitude coordinate pair shared across map providers,
/// routing helpers, and search results.
class RoadixGeoPoint {
  final double latitude;
  final double longitude;

  const RoadixGeoPoint(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadixGeoPoint &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      'RoadixGeoPoint(${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})';
}
