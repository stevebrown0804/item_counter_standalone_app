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
part 'ui/sheets/MainScreen.dart';
part 'ui/sheets/SettingsScreen.dart';
part 'ui/settings/TimeZoneSetting.dart';
part 'ui/settings/AveragingWindow.dart';
part 'ui/settings/SkipSecondConfirmation.dart';
part 'ui/settings/ViewTransactionsButton.dart';
part 'ui/settings/sheets/TransactionViewerSheet.dart';
part 'ui/settings/sheets/TransactionEditorSheet.dart';
part 'ui/settings/ExportDatabase.dart';
part 'ui/settings/DangerZoneHeader.dart';
part 'ui/settings/DeleteOutdatedTransactions.dart';
part 'ui/sheets/LogPillsSheet.dart';

/// The DB's filename
const String kDbFileName = 'daily-pill-tracking.db';

enum _TxMode { today, lastNDays, range, all }
// </editor-fold>

// <editor-fold desc="the ItemCounterApp class; main()">
class ItemCounterApp extends StatelessWidget {
  const ItemCounterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Item Counter',
      home: const _MainScreen(),
    );
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'item_tracker';
  }

  tzdata.initializeTimeZones();

  runApp(const ItemCounterApp());
}
// </editor-fold>
