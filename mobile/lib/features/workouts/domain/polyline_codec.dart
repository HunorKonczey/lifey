/// Google's encoded polyline algorithm format
/// (https://developers.google.com/maps/documentation/utilities/polylinealgorithm,
/// docs/cardio/54-cardio-gps-route-plan.md §5 point 2: "5 tizedes... kb.
/// 8-10 bájt/pont") — delta-encoded, zigzag-signed, base64-like 5-bit chunks
/// offset by 63 into printable ASCII. [encodePolyline]/[decodePolyline] are
/// the plain two-channel (lat, lng) form, exactly as the spec defines it.
///
/// `route_encoder.dart` never calls these directly on a whole session's
/// route — [encodePolyline3]/[decodePolyline3] below extend the same
/// primitive with a third interleaved channel (altitude) so a single
/// encoded string can carry the durable elevation profile too (see
/// `route_encoder.dart`'s doc for why: the plan's D-C4.2 wants one string to
/// be the whole cross-device source of truth, and altitude has nowhere else
/// to live once the raw `CardioTrackPoints` are pruned after 90 days).
library;

const _coordinatePrecision = 1e5;

/// Altitude precision: 0.1 m — plenty for a profile chart, and keeps the
/// encoded deltas small (altitude changes far less per point than lat/lng
/// does at 5-decimal precision).
const _altitudePrecision = 1e1;

String encodePolyline(List<(double lat, double lng)> points) {
  final buffer = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;
  for (final (lat, lng) in points) {
    final latE = _round(lat * _coordinatePrecision);
    final lngE = _round(lng * _coordinatePrecision);
    _encodeValue(latE - prevLat, buffer);
    _encodeValue(lngE - prevLng, buffer);
    prevLat = latE;
    prevLng = lngE;
  }
  return buffer.toString();
}

List<(double lat, double lng)> decodePolyline(String encoded) {
  final points = <(double, double)>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  while (index < encoded.length) {
    final decodedLat = _decodeValue(encoded, index);
    lat += decodedLat.value;
    index = decodedLat.nextIndex;
    final decodedLng = _decodeValue(encoded, index);
    lng += decodedLng.value;
    index = decodedLng.nextIndex;
    points.add((lat / _coordinatePrecision, lng / _coordinatePrecision));
  }
  return points;
}

String encodePolyline3(List<(double lat, double lng, double alt)> points) {
  final buffer = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;
  var prevAlt = 0;
  for (final (lat, lng, alt) in points) {
    final latE = _round(lat * _coordinatePrecision);
    final lngE = _round(lng * _coordinatePrecision);
    final altE = _round(alt * _altitudePrecision);
    _encodeValue(latE - prevLat, buffer);
    _encodeValue(lngE - prevLng, buffer);
    _encodeValue(altE - prevAlt, buffer);
    prevLat = latE;
    prevLng = lngE;
    prevAlt = altE;
  }
  return buffer.toString();
}

List<(double lat, double lng, double alt)> decodePolyline3(String encoded) {
  final points = <(double, double, double)>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  var alt = 0;
  while (index < encoded.length) {
    final decodedLat = _decodeValue(encoded, index);
    lat += decodedLat.value;
    index = decodedLat.nextIndex;
    final decodedLng = _decodeValue(encoded, index);
    lng += decodedLng.value;
    index = decodedLng.nextIndex;
    final decodedAlt = _decodeValue(encoded, index);
    alt += decodedAlt.value;
    index = decodedAlt.nextIndex;
    points.add((lat / _coordinatePrecision, lng / _coordinatePrecision, alt / _altitudePrecision));
  }
  return points;
}

int _round(double value) => value.round();

void _encodeValue(int value, StringBuffer buffer) {
  var shifted = value < 0 ? ~(value << 1) : (value << 1);
  while (shifted >= 0x20) {
    buffer.writeCharCode((0x20 | (shifted & 0x1f)) + 63);
    shifted >>= 5;
  }
  buffer.writeCharCode(shifted + 63);
}

({int value, int nextIndex}) _decodeValue(String encoded, int index) {
  var result = 0;
  var shift = 0;
  int chunk;
  do {
    chunk = encoded.codeUnitAt(index) - 63;
    index++;
    result |= (chunk & 0x1f) << shift;
    shift += 5;
  } while (chunk >= 0x20);
  final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  return (value: value, nextIndex: index);
}
