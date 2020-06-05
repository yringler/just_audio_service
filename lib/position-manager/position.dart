import 'package:hive/hive.dart';

part 'position.g.dart';

/// Keep track of the last position of an audio file.
@HiveType(typeId: 0)
class Position extends HiveObject {
  Position({Duration position, String id}) {
    if (position != null) {
      this.position = position;
    }
    this.id = id;
  }

  /// When the file was created, or the position was last updated.
  DateTime get createdDate => DateTime.fromMillisecondsSinceEpoch(_createdDate);

  Duration get position => Duration(milliseconds: _position ?? 0);

  set position(Duration position) {
    _position = position?.inMilliseconds ?? 0;
  }

  /// Expose the id whose position is being described, independent of hive storage.
  String get id {
    return key ?? _id;
  }

  set id(String id) => _id = id;

  @HiveField(0)
  int _position;

  @HiveField(1)
  int _createdDate;

  String _id;
}
