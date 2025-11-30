//REMINDER: Path (Medium Phone API 36.0):
// Full path: /data/data/com.example.daily_pill_counter
// Pastable piece: com.example.daily_pill_counter

// <editor-fold desc="Imports, consts, main, etc.">
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as ffi_helpers;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:media_store_plus/media_store_plus.dart';
import 'package:flutter/services.dart'; // for FilteringTextInputFormatter
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

part 'ffi.dart';
part 'store.dart';
part 'db.dart';
part 'ui_ViewScreen.dart';
part 'ui_Settings_Screen.dart';
part 'ui_Settings_TimeZoneSetting.dart';
part 'ui_Settings_AveragingWindow.dart';
part 'ui_Settings_SkipSecondConfirmation.dart';

/// Filenames / view names must match your existing DB.
const String kDbFileName = 'daily-pill-tracking.db';
const String kViewName = 'daily_avg_by_pill_UTC';

/// Column names expected from the daily-avg view.
const List<String> kShowColumns = ['pill_name', 'daily_avg'];

// --- Transaction viewer types (top-level) ---
enum _TxMode { today, lastNDays, range, all }

// </editor-fold>

// <editor-fold desc="Some fn; the _TxRow, PillApp and _DB classes">

Future<DateTime?> _pickLocalDateTime(
    BuildContext context, {
      required tz.Location loc,
      DateTime? initialLocal,
    })
  async {
  final nowL = tz.TZDateTime.now(loc);
  final initial = initialLocal ?? nowL;

  final d = await showDatePicker(
    context: context,
    initialDate: DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (d == null) return null;

  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );

  if (t == null) return null;

  return tz.TZDateTime(loc, d.year, d.month, d.day, t.hour, t.minute);
}

class _TxRow {
  final DateTime utc; // stored in UTC
  final String pill;
  final int qty;
  const _TxRow(this.utc, this.pill, this.qty);
}

class PillApp extends StatelessWidget {
  const PillApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pill tracker',
      home: const _ViewScreen(),
    );
  }
}

// </editor-fold>

// <editor-fold desc="main()">
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'daily_pill_tracking';
  }
  tzdata.initializeTimeZones();
  runApp(const PillApp());
}
// </editor-fold>
