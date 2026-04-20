// main.dart

// <editor-fold desc="Imports, consts, main, etc.">
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:media_store_plus/media_store_plus.dart';
import 'package:flutter/services.dart'; // for FilteringTextInputFormatter
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

part 'store.dart';
part 'db.dart';
part 'db.models.dart';
part 'db.internals.dart';
part 'ui/sheets/MainScreen.dart';
part 'ui/sheets/SettingsScreen.dart';
part 'ui/settings/TimeZoneSetting.dart';
part 'ui/settings/AveragingWindow.dart';
part 'ui/settings/SkipSecondConfirmation.dart';
part 'ui/settings/ViewTransactionsButton.dart';
part 'ui/settings/sheets/TransactionViewerSheet.dart';
part 'ui/settings/sheets/TransactionEditorSheet.dart';
part 'ui/settings/sheets/EditCountableItems.dart';
part 'ui/settings/ExportDatabase.dart';
part 'ui/settings/ImportDatabase.dart';
part 'ui/settings/DangerZoneHeader.dart';
part 'ui/settings/DeleteOutdatedTransactions.dart';
part 'ui/sheets/AddItemsSheet.dart';

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

Future<void> _initializePlatformServices() async {
  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'item_tracker';
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  runApp(const ItemCounterApp());
  unawaited(_initializePlatformServices());
}
// </editor-fold>
