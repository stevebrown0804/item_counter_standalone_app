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

  static DateTime _utcDateOnly(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
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

  static DateTime? parseDashDate(String raw) {
    final parts = raw.trim().split('-');
    if (parts.length != 3) {
      return null;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }

    final parsedDate = DateTime(year, month, day);
    if (parsedDate.year != year || parsedDate.month != month || parsedDate.day != day) {
      return null;
    }

    return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  }

  static DateTime? parseDashTimestampMinutes(String raw) {
    if (raw.trim() == 'Now') {
      return null;
    }

    final parts = raw.trim().split(' ');
    if (parts.length != 2) {
      return null;
    }

    final date = parseDashDate(parts[0]);
    if (date == null) {
      return null;
    }

    final timeParts = parts[1].split(':');
    if (timeParts.length != 2) {
      return null;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    final parsed = DateTime(date.year, date.month, date.day, hour, minute);
    if (parsed.year != date.year ||
        parsed.month != date.month ||
        parsed.day != date.day ||
        parsed.hour != hour ||
        parsed.minute != minute) {
      return null;
    }

    return parsed;
  }

  static DateTime? parseDashTimestampSeconds(String raw) {
    final parts = raw.trim().split(' ');
    if (parts.length != 2) {
      return null;
    }

    final date = parseDashDate(parts[0]);
    if (date == null) {
      return null;
    }

    final timeParts = parts[1].split(':');
    if (timeParts.length < 2 || timeParts.length > 3) {
      return null;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    int second = 0;
    if (timeParts.length == 3) {
      final parsedSecond = int.tryParse(timeParts[2]);
      if (parsedSecond == null) {
        return null;
      }
      second = parsedSecond;
    }

    final parsed = DateTime(date.year, date.month, date.day, hour, minute, second);
    if (parsed.year != date.year ||
        parsed.month != date.month ||
        parsed.day != date.day ||
        parsed.hour != hour ||
        parsed.minute != minute ||
        parsed.second != second) {
      return null;
    }

    return parsed;
  }

  static String twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  static String formatSlashDate(DateTime date) {
    return '${twoDigits(date.month)}/${twoDigits(date.day)}/${date.year.toString().padLeft(4, '0')}';
  }

  static String formatDashDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${twoDigits(date.month)}-${twoDigits(date.day)}';
  }

  static String formatDashTimestampMinutes(DateTime date) {
    return '${formatDashDate(date)} ${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  static String formatDbTimestamp(DateTime date) {
    return '${formatDashDate(date)} ${twoDigits(date.hour)}:${twoDigits(date.minute)}:${twoDigits(date.second)}';
  }

  static String normalizeDbLikeTimestamp(String s) {
    final trimmed = s.trim();
    if (trimmed.endsWith('+00:00')) {
      return trimmed.substring(0, trimmed.length - 6).trim();
    }
    if (trimmed.endsWith('Z')) {
      return trimmed.substring(0, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  static DateTime parseNaiveTimestamp(String s) {
    final norm = normalizeDbLikeTimestamp(s);
    final parsed = DateTime.parse(norm.replaceFirst(' ', 'T'));
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    );
  }

  static int positiveElapsedDays({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final rawDays = _utcDateOnly(endDate).difference(_utcDateOnly(startDate)).inDays;
    return rawDays <= 0 ? 1 : rawDays;
  }

  static int daysAgoFromDate({
    required DateTime date,
    required String tzName,
  }) {
    final today = todayDateOnly(tzName);
    return positiveElapsedDays(
      startDate: date,
      endDate: today,
    );
  }

  static DateTime startDateFromDaysAgo({
    required int daysAgo,
    required String tzName,
  }) {
    final today = todayDateOnly(tzName);
    final utcStart = _utcDateOnly(today).subtract(Duration(days: daysAgo));
    return DateTime(utcStart.year, utcStart.month, utcStart.day);
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
        startDateFromDaysAgo(
          daysAgo: settings.numberOfDaysAgo,
          tzName: tzName,
        );

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