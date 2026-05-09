part of 'main.dart';

DateTime parseDbUtc(String s) {
  final base = s.replaceFirst(' ', 'T');
  final iso = base.endsWith('+00:00') ? base.replaceFirst('+00:00', 'Z') : '${base}Z';

  return DateTime.parse(iso).toUtc();
}

class _AppDateLogic {
  static tz.Location locationOrUtc(String tzName) {
    try {
      return tz.getLocation(tzName);
    } catch (_) {
      return tz.getLocation('Etc/UTC');
    }
  }

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime todayDateOnly(String tzName) {
    final loc = locationOrUtc(tzName);
    final now = tz.TZDateTime.now(loc);
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime? parseSlashDate(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) {
      return null;
    }

    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) {
      return null;
    }

    final parsedDate = DateTime(year, month, day);
    if (parsedDate.year != year || parsedDate.month != month || parsedDate.day != day) {
      return null;
    }

    return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  }

  static String formatSlashDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  static int elapsedDays({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final rawDays = dateOnly(endDate).difference(dateOnly(startDate)).inDays;
    return rawDays <= 0 ? 1 : rawDays;
  }

  static String? buildAverageWindowTooltip(
      _DailyAverageSettings settings,
      String tzName,
      ) {
    if (!settings.pinStartDate) {
      return null;
    }

    final today = todayDateOnly(tzName);
    final startDate = parseSlashDate(settings.startDate) ??
        today.subtract(Duration(days: settings.numberOfDaysAgo));

    if (!settings.pinEndDate) {
      return '${formatSlashDate(startDate)} to today';
    }

    final endDate = parseSlashDate(settings.endDate) ?? today;
    return '${formatSlashDate(startDate)} to ${formatSlashDate(endDate)}';
  }
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