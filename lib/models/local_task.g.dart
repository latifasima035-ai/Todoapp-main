// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalTaskAdapter extends TypeAdapter<LocalTask> {
  @override
  final int typeId = 0;

  @override
  LocalTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalTask(
      id: fields[0] as int?,
      userId: fields[1] as int,
      name: fields[2] as String,
      category: fields[3] as String,
      frequency: fields[4] as String,
      icon: fields[5] as String,
      target: fields[6] as int,
      reminderTime: fields[7] as String,
      hasReminder: fields[8] as bool,
      daysSelected: fields[9] as String,
      createdAt: fields[10] as DateTime,
      isSynced: fields[11] as bool,
      syncStatus: fields[12] as String,
      operationType: fields[13] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LocalTask obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.frequency)
      ..writeByte(5)
      ..write(obj.icon)
      ..writeByte(6)
      ..write(obj.target)
      ..writeByte(7)
      ..write(obj.reminderTime)
      ..writeByte(8)
      ..write(obj.hasReminder)
      ..writeByte(9)
      ..write(obj.daysSelected)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.isSynced)
      ..writeByte(12)
      ..write(obj.syncStatus)
      ..writeByte(13)
      ..write(obj.operationType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
