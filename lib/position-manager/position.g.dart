// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'position.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PositionAdapter extends TypeAdapter<Position> {
  @override
  final typeId = 0;

  @override
  Position read(BinaryReader reader) {
    var numOfFields = reader.readByte();
    var fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Position(
      id: fields[2] as String,
    )
      .._position = fields[0] as int
      .._createdDate = fields[1] as int;
  }

  @override
  void write(BinaryWriter writer, Position obj) {
    writer
      ..writeByte(3)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(0)
      ..write(obj._position)
      ..writeByte(1)
      ..write(obj._createdDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
