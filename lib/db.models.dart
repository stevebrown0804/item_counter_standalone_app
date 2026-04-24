// db.models.dart

part of 'main.dart';

DateTime parseDbUtc(String s) {
  final base = s.replaceFirst(' ', 'T');
  final iso = base.endsWith('+00:00') ? base.replaceFirst('+00:00', 'Z') : '${base}Z';

  return DateTime.parse(iso).toUtc();
}

class _Item {
  final int id;
  final String name;
  final int? displayOrder;
  final bool showItem;

  _Item(this.id, this.name, this.displayOrder, this.showItem);
}

class _AvgRow {
  final String itemName;
  final double avg;

  _AvgRow(this.itemName, this.avg);
}

class _DailyAverageSettings {
  final int numberOfDaysAgo;
  final String startDate;
  final String endDate;
  final bool pinStartDate;
  final bool pinEndDate;

  _DailyAverageSettings({
    required this.numberOfDaysAgo,
    required this.startDate,
    required this.endDate,
    required this.pinStartDate,
    required this.pinEndDate,
  });
}

class _Entry {
  final int itemId;
  final int qty;

  _Entry(this.itemId, this.qty);
}

class _TxRow {
  final int id;
  final DateTime utc;
  final String item;
  final int qty;

  const _TxRow(this.id, this.utc, this.item, this.qty);
}

class _TxnSnapshot {
  final int itemId;
  final int qty;
  final String utcIso;

  _TxnSnapshot(this.itemId, this.qty, this.utcIso);
}

class _SchemaObject {
  final String type;
  final String name;
  final String tableName;
  final String sql;

  _SchemaObject(this.type, this.name, this.tableName, this.sql);
}

class _TzAliasGroup {
  final String tzName;
  final String display;
  final List<String> aliases;

  _TzAliasGroup(this.tzName, this.display, this.aliases);
}

class _Tz {
  final String alias;
  final String tzName;

  _Tz(this.alias, this.tzName);
}