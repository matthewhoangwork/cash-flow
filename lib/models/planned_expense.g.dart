// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planned_expense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlannedExpenseAdapter extends TypeAdapter<PlannedExpense> {
  @override
  final typeId = 4;

  @override
  PlannedExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedExpense(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      year: (fields[3] as num).toInt(),
      month: (fields[4] as num).toInt(),
      categoryId: fields[5] as String?,
      note: fields[6] == null ? '' : fields[6] as String,
      updatedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedExpense obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.year)
      ..writeByte(4)
      ..write(obj.month)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
