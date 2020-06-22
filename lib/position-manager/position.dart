import 'package:hive/hive.dart';

part 'position.g.dart';

/// Keep track of the last position of an audio file.
@HiveType(typeId: 0)
class Position extends HiveObject {
  Position({Duration position, this.id}) {
    if (position != null) {
      this.position = position;
    }

    _createdDate = DateTime.now().millisecondsSinceEpoch;
  }

  /// When the file was created, or the position was last updated.
  /// If [_createdDate] isn't set, consider it as being 0, which makes the record very old, and will probably be
  /// deleted soon.
  DateTime get createdDate =>
      DateTime.fromMillisecondsSinceEpoch(_createdDate ?? 0);

  Duration get position => Duration(milliseconds: _position ?? 0);

  set position(Duration position) {
    _position = position?.inMilliseconds ?? 0;
  }

  /// Expose the id whose position is being described, independent of hive storage.
  /// This is important because the hive id is truncated according to hive requirements.
  @HiveField(2)
  String id;

  @HiveField(0)
  int _position;

  @HiveField(1)
  int _createdDate;
}
