/// Which way the person faces in a progress photo (docs/80). [wire] is the
/// backend enum name; [other] is the untagged default.
enum PhotoPose {
  front('FRONT'),
  side('SIDE'),
  back('BACK'),
  other('OTHER');

  const PhotoPose(this.wire);

  final String wire;

  /// Falls back to [other] for a name this build does not know, so a pose
  /// added by a newer backend still shows the photo.
  static PhotoPose fromWire(String? value) {
    for (final pose in values) {
      if (pose.wire == value) return pose;
    }
    return other;
  }
}

/// One progress photo's metadata (`/progress-photos`). The bytes are fetched
/// separately — a timeline of these never carries image data (docs/80 §2.5).
class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.takenOn,
    required this.pose,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
        id: json['id'] as int,
        takenOn: DateTime.parse(json['takenOn'] as String),
        pose: PhotoPose.fromWire(json['pose'] as String?),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  /// The server id — a photo only exists once it has uploaded.
  final int id;

  /// The calendar day the photo was taken (a date, no time).
  final DateTime takenOn;
  final PhotoPose pose;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}
