// /ui/settings/sheets/TransactionViewerSheet.dart

part of '../../../main.dart';

enum _TransactionDeleteAction {
  confirm,
}

class _TransactionViewerDateBounds {
  _TransactionViewerDateBounds({
    required this.oldestTransactionDateOnly,
    required this.todayDateOnly,
    required this.yesterdayDateOnly,
  });

  final DateTime? oldestTransactionDateOnly;
  final DateTime todayDateOnly;
  final DateTime yesterdayDateOnly;

  DateTime startPickerFirstDate() {
    final oldestDate = oldestTransactionDateOnly;
    if (oldestDate == null) {
      return yesterdayDateOnly;
    }

    if (oldestDate.isAfter(yesterdayDateOnly)) {
      return yesterdayDateOnly;
    }

    return oldestDate;
  }

  DateTime startPickerLastDate() {
    return yesterdayDateOnly;
  }

  DateTime endPickerFirstDate() {
    final oldestDate = oldestTransactionDateOnly;
    if (oldestDate == null) {
      return todayDateOnly;
    }

    final oneDayAfterOldest = DateTime(
      oldestDate.year,
      oldestDate.month,
      oldestDate.day + 1,
    );

    if (oneDayAfterOldest.isAfter(todayDateOnly)) {
      return todayDateOnly;
    }

    return oneDayAfterOldest;
  }

  DateTime endPickerLastDate() {
    return todayDateOnly;
  }
}

class _TransactionViewerState {
  _TransactionViewerState({
    required this.db,
    required this.store,
    required this.onBackPressed,
  })  : tzName = store.activeTz.tzName,
        loc = _AppDateLogic.locationOrUtc(store.activeTz.tzName);

  final _Db db;
  final _Store store;
  final Future<void> Function() onBackPressed;
  final String tzName;
  final tz.Location loc;
  final TextEditingController lastDaysCtrl = TextEditingController();

  _TxMode mode = _TxMode.today;
  DateTime? startLocal;
  DateTime? endLocal;
  List<_TxRow> items = [];
  bool busy = false;
  bool filterNeedsApply = false;
  String? error;
  int? selectedIndex;
  late final _TransactionViewerDateBounds dateBounds;
  late final int lastDaysTextBoxDigitCount;

  Future<void> initialize() async {
    final oldestDate = await readOldestTransactionDateOnly();
    dateBounds = _TransactionViewerDateBounds(
      oldestTransactionDateOnly: oldestDate,
      todayDateOnly: _AppDateLogic.todayDateOnly(tzName),
      yesterdayDateOnly: _AppDateLogic.startDateFromDaysAgo(
        daysAgo: 1,
        tzName: tzName,
      ),
    );
    lastDaysTextBoxDigitCount = await readOldestTransactionDigitCountForLastDaysBox();
  }

  Future<DateTime?> readOldestTransactionDateOnly() async {
    final oldestLocal = await db.readOldestTransactionLocalDate();
    if (oldestLocal == null) {
      return null;
    }

    return DateTime(
      oldestLocal.year,
      oldestLocal.month,
      oldestLocal.day,
    );
  }

  Future<int> readOldestTransactionDigitCountForLastDaysBox() async {
    final oldestDate = await readOldestTransactionDateOnly();
    if (oldestDate == null) {
      return 1;
    }

    final daysAgo = _AppDateLogic.daysAgoFromDate(
      date: oldestDate,
      tzName: tzName,
    );

    final digitCount = daysAgo.toString().length;
    return digitCount < 1 ? 1 : digitCount;
  }

  int? parseLastDaysInput() {
    final raw = lastDaysCtrl.text.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(raw)) {
      return null;
    }

    return int.parse(raw);
  }

  Future<int?> oldestTransactionDaysAgo() async {
    final oldestDate = await readOldestTransactionDateOnly();
    if (oldestDate == null) {
      return null;
    }

    return _AppDateLogic.daysAgoFromDate(
      date: oldestDate,
      tzName: tzName,
    );
  }

  void setLastDaysText(int days) {
    final text = days.toString();
    lastDaysCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  bool lastDaysFilterIsValid() {
    return parseLastDaysInput() != null;
  }

  void setModeAndMarkFilterNeedsApply(_TxMode nextMode) {
    mode = nextMode;
    filterNeedsApply = mode != _TxMode.lastNDays || lastDaysFilterIsValid();
  }

  void markFilterNeedsApply() {
    filterNeedsApply = mode != _TxMode.lastNDays || lastDaysFilterIsValid();
  }

  void resetFilters() {
    mode = _TxMode.today;
    lastDaysCtrl.clear();
    startLocal = null;
    endLocal = null;
    filterNeedsApply = false;
    selectedIndex = null;
  }

  bool canApplyFilter() {
    return filterNeedsApply &&
        !busy &&
        (mode != _TxMode.lastNDays || lastDaysFilterIsValid());
  }

  String formatLocalForField(DateTime? value) {
    if (value == null) {
      return '';
    }

    return _AppDateLogic.formatDashTimestampMinutes(value);
  }

  String endDateDisplayText() {
    if (endLocal == null) {
      return 'Today';
    }

    return formatLocalForField(endLocal);
  }

  Future<void> runQuery() async {
    busy = true;
    error = null;

    try {
      switch (mode) {
        case _TxMode.today:
          items = await db.queryTransactionsToday();
          break;

        case _TxMode.lastNDays:
          items = await _queryLastNDays();
          break;

        case _TxMode.range:
          items = await _queryRange();
          break;

        case _TxMode.all:
          items = await db.queryTransactionsAll();
          break;
      }

      filterNeedsApply = false;
    } catch (ex) {
      error = ex.toString();
    } finally {
      busy = false;
    }
  }

  Future<List<_TxRow>> _queryLastNDays() async {
    final requestedDays = parseLastDaysInput();
    if (requestedDays == null) {
      throw StateError('Enter a non-negative integer for Last # days.');
    }

    final effectiveRequestedDays = requestedDays == 0 ? 1 : requestedDays;
    final oldestDays = await oldestTransactionDaysAgo();
    final days = oldestDays == null || effectiveRequestedDays <= oldestDays
        ? effectiveRequestedDays
        : oldestDays;

    if (days != requestedDays) {
      setLastDaysText(days);
    }

    return db.queryTransactionsLastNDays(days);
  }

  Future<List<_TxRow>> _queryRange() {
    final startStr = startLocal == null
        ? null
        : _AppDateLogic.formatDbTimestamp(startLocal!);
    final endStr = endLocal == null
        ? null
        : _AppDateLogic.formatDbTimestamp(endLocal!);

    return db.queryTransactionsRangeLocal(
      startLocal: startStr,
      endLocal: endStr,
    );
  }

  void dispose() {
    lastDaysCtrl.dispose();
  }
}

Future<DateTime?> _pickLocalDateTime(
  BuildContext context, {
  required tz.Location loc,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialLocal,
}) async {
  final nowLocal = tz.TZDateTime.now(loc);
  final initial = initialLocal ?? nowLocal;

  DateTime initialDate = DateTime(initial.year, initial.month, initial.day);
  if (initialDate.isBefore(firstDate)) {
    initialDate = firstDate;
  }
  if (initialDate.isAfter(lastDate)) {
    initialDate = lastDate;
  }

  final d = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (d == null) return null;

  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );

  if (t == null) return null;

  return tz.TZDateTime(loc, d.year, d.month, d.day, t.hour, t.minute);
}

Future<void> doTransactionViewerSheet({
  required BuildContext context,
  required _Db db,
  required _Store store,
  required Future<void> Function() onBackPressed,
}) async {
  final state = _TransactionViewerState(
    db: db,
    store: store,
    onBackPressed: onBackPressed,
  );

  await state.initialize();
  await state.runQuery();
  if (!context.mounted) return;

  final sheetFuture = _showTransactionViewerBottomSheet(
    context: context,
    state: state,
  );
  sheetFuture.whenComplete(state.dispose);
}

Future<void> _showTransactionViewerBottomSheet({
  required BuildContext context,
  required _TransactionViewerState state,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          void ss(VoidCallback f) {
            if (context.mounted) setSheetState(f);
          }

          return _buildTransactionViewerSheetContent(
            hostContext: context,
            sheetContext: ctx,
            state: state,
            setSheetState: ss,
          );
        },
      );
    },
  );
}

Widget _buildTransactionViewerSheetContent({
  required BuildContext hostContext,
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: _bottomSheetBottomPadding(
          sheetContext,
          _standardBottomSheetBottomPadding,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTransactionViewerHeader(
            sheetContext: sheetContext,
            state: state,
            setSheetState: setSheetState,
          ),
          const SizedBox(height: 4),
          _buildTransactionViewerFilterSection(
            hostContext: hostContext,
            sheetContext: sheetContext,
            state: state,
            setSheetState: setSheetState,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          _buildTransactionViewerError(sheetContext, state.error),
          const SizedBox(height: 8),
          _buildTransactionList(
            sheetContext: sheetContext,
            state: state,
            setSheetState: setSheetState,
          ),
          const SizedBox(height: 12),
          _buildTransactionActionButtons(
            sheetContext: sheetContext,
            state: state,
            setSheetState: setSheetState,
          ),
        ],
      ),
    ),
  );
}

Widget _buildTransactionViewerHeader({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return Row(
    children: [
      IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () async {
          Navigator.of(sheetContext).pop();
          await state.onBackPressed();
        },
      ),
      const SizedBox(width: 4),
      const Text(
        'Transaction Viewer',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      const Spacer(),
      IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh),
        onPressed: state.busy
            ? null
            : () async {
                await state.runQuery();
                setSheetState(() {
                  state.selectedIndex = null;
                });
              },
      ),
    ],
  );
}

Widget _buildTransactionViewerFilterSection({
  required BuildContext hostContext,
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return Column(
    children: [
      _buildTransactionViewerRadioRow(
        state: state,
        setSheetState: setSheetState,
        mode: _TxMode.today,
        trailing: const Text('Today'),
      ),
      const Divider(),
      _buildTransactionViewerRadioRow(
        state: state,
        setSheetState: setSheetState,
        mode: _TxMode.lastNDays,
        trailing: _buildLastNDaysFilter(
          sheetContext: sheetContext,
          state: state,
          setSheetState: setSheetState,
        ),
      ),
      const Divider(),
      _buildTransactionViewerRadioRow(
        state: state,
        setSheetState: setSheetState,
        mode: _TxMode.range,
        trailing: _buildRangeFilter(
          hostContext: hostContext,
          sheetContext: sheetContext,
          state: state,
          setSheetState: setSheetState,
        ),
      ),
      const Divider(),
      _buildTransactionViewerRadioRow(
        state: state,
        setSheetState: setSheetState,
        mode: _TxMode.all,
        trailing: const Text('All'),
      ),
      _buildFilterButtons(
        state: state,
        setSheetState: setSheetState,
      ),
    ],
  );
}

Widget _buildTransactionViewerRadioRow({
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
  required _TxMode mode,
  required Widget trailing,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Radio<_TxMode>(
        value: mode,
        groupValue: state.mode,
        onChanged: (v) {
          if (v == null) {
            return;
          }

          setSheetState(() {
            state.setModeAndMarkFilterNeedsApply(v);
          });
        },
      ),
      const SizedBox(width: 4),
      Expanded(child: trailing),
    ],
  );
}

Widget _buildLastNDaysFilter({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  final inputStyle = Theme.of(sheetContext).textTheme.bodyMedium;
  final lastDaysTextBoxWidth = _measureLastDaysTextBoxWidth(
    context: sheetContext,
    digitCount: state.lastDaysTextBoxDigitCount,
    textStyle: inputStyle,
  );

  return Row(
    children: [
      const Text('Last'),
      const SizedBox(width: 8),
      SizedBox(
        width: lastDaysTextBoxWidth,
        child: TextField(
          controller: state.lastDaysCtrl,
          keyboardType: TextInputType.number,
          style: inputStyle,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: _lastDaysInputDecoration(),
          onTap: () {
            setSheetState(() {
              state.setModeAndMarkFilterNeedsApply(_TxMode.lastNDays);
            });
          },
          onChanged: (_) {
            setSheetState(state.markFilterNeedsApply);
          },
        ),
      ),
      const SizedBox(width: 8),
      const Text('days'),
    ],
  );
}

double _measureLastDaysTextBoxWidth({
  required BuildContext context,
  required int digitCount,
  required TextStyle? textStyle,
}) {
  const horizontalContentPadding = 12.0;
  const borderWidthPerSide = 1.0;
  const extraInteriorSlack = 20.0;

  final widestDigit = _widestDigit(
    context: context,
    style: textStyle,
  );
  final widestLastDaysString = List<String>.filled(
    digitCount,
    widestDigit,
  ).join();
  final lastDaysTextWidth = _measureTextWidth(
    context: context,
    text: widestLastDaysString,
    style: textStyle,
  );

  return lastDaysTextWidth +
      (horizontalContentPadding * 2) +
      (borderWidthPerSide * 2) +
      extraInteriorSlack;
}

InputDecoration _lastDaysInputDecoration() {
  const horizontalContentPadding = 12.0;
  const verticalContentPadding = 8.0;

  return const InputDecoration(
    isDense: true,
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(
      horizontal: horizontalContentPadding,
      vertical: verticalContentPadding,
    ),
  );
}

double _measureTextWidth({
  required BuildContext context,
  required String text,
  required TextStyle? style,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: style,
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();

  return painter.width;
}

String _widestDigit({
  required BuildContext context,
  required TextStyle? style,
}) {
  var widest = '0';
  var widestWidth = 0.0;

  for (final digit in const <String>[
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ]) {
    final width = _measureTextWidth(
      context: context,
      text: digit,
      style: style,
    );
    if (width > widestWidth) {
      widestWidth = width;
      widest = digit;
    }
  }

  return widest;
}

Widget _buildRangeFilter({
  required BuildContext hostContext,
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildStartDateRow(
        hostContext: hostContext,
        state: state,
        setSheetState: setSheetState,
      ),
      const SizedBox(height: 4),
      _buildEndDateRow(
        hostContext: hostContext,
        sheetContext: sheetContext,
        state: state,
        setSheetState: setSheetState,
      ),
    ],
  );
}

Widget _buildStartDateRow({
  required BuildContext hostContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  final startText = state.formatLocalForField(state.startLocal);

  return Row(
    children: [
      const Text('From'),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          readOnly: true,
          controller: TextEditingController(text: startText),
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            hintText: startText.isEmpty ? '— select date —' : null,
            hintStyle: const TextStyle(color: Colors.grey),
          ),
          onTap: () {
            setSheetState(() {
              state.setModeAndMarkFilterNeedsApply(_TxMode.range);
            });
          },
        ),
      ),
      const SizedBox(width: 8),
      TextButton(
        onPressed: () async {
          setSheetState(() {
            state.setModeAndMarkFilterNeedsApply(_TxMode.range);
          });
          final picked = await _pickLocalDateTime(
            hostContext,
            loc: state.loc,
            firstDate: state.dateBounds.startPickerFirstDate(),
            lastDate: state.dateBounds.startPickerLastDate(),
            initialLocal: state.startLocal,
          );
          if (picked == null) {
            return;
          }
          setSheetState(() {
            state.startLocal = picked;
            state.filterNeedsApply = true;
          });
        },
        child: const Text('Pick start date'),
      ),
    ],
  );
}

Widget _buildEndDateRow({
  required BuildContext hostContext,
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('to'),
          const SizedBox(width: 26),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                TextField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: state.endDateDisplayText(),
                  ),
                  style: state.endLocal == null
                      ? TextStyle(
                          color: Theme.of(sheetContext).hintColor,
                        )
                      : null,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onTap: () {
                    setSheetState(() {
                      state.setModeAndMarkFilterNeedsApply(_TxMode.range);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () async {
              setSheetState(() {
                state.setModeAndMarkFilterNeedsApply(_TxMode.range);
              });
              final picked = await _pickLocalDateTime(
                hostContext,
                loc: state.loc,
                firstDate: state.dateBounds.endPickerFirstDate(),
                lastDate: state.dateBounds.endPickerLastDate(),
                initialLocal: state.endLocal,
              );
              if (picked == null) {
                return;
              }
              setSheetState(() {
                state.endLocal = picked;
                state.filterNeedsApply = true;
              });
            },
            child: const Text('Pick end date'),
          ),
        ],
      ),
      const SizedBox(height: 4),
    ],
  );
}

Widget _buildFilterButtons({
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return Align(
    alignment: Alignment.center,
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildApplyFilterButton(
          state: state,
          setSheetState: setSheetState,
        ),
        _buildResetFiltersButton(
          state: state,
          setSheetState: setSheetState,
        ),
      ],
    ),
  );
}

Widget _buildApplyFilterButton({
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  if (!state.canApplyFilter()) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.search),
      label: const Text('Apply filter'),
      onPressed: null,
    );
  }

  return FilledButton.icon(
    icon: const Icon(Icons.search),
    label: const Text('Apply filter'),
    onPressed: () async {
      FocusManager.instance.primaryFocus?.unfocus();
      await state.runQuery();
      setSheetState(() {
        // Clear any selected transaction after applying a new filter.
        state.selectedIndex = null;
      });
    },
  );
}

Widget _buildResetFiltersButton({
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return OutlinedButton.icon(
    icon: const Icon(Icons.restart_alt),
    label: const Text('Reset filters'),
    onPressed: () async {
      FocusManager.instance.primaryFocus?.unfocus();
      setSheetState(state.resetFilters);
      await state.runQuery();
      setSheetState(() {});
    },
  );
}

Widget _buildTransactionViewerError(BuildContext context, String? error) {
  if (error == null) {
    return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      error,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

Widget _buildTransactionList({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return Flexible(
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(sheetContext).dividerColor,
        ),
      ),
      child: Column(
        children: [
          _buildTransactionListHeader(),
          const Divider(height: 1),
          _buildTransactionListBody(
            sheetContext: sheetContext,
            state: state,
            setSheetState: setSheetState,
          ),
        ],
      ),
    ),
  );
}

Widget _buildTransactionListHeader() {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    child: Row(
      children: const [
        Expanded(
          flex: 44,
          child: Text('Timestamp'),
        ),
        Expanded(
          flex: 44,
          child: Text('Item name'),
        ),
        Expanded(
          flex: 12,
          child: Text(
            'Qty.',
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

Widget _buildTransactionListBody({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return Expanded(
    child: state.busy
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: state.items.length,
            itemBuilder: (c, i) {
              return _buildTransactionListRow(
                sheetContext: sheetContext,
                state: state,
                index: i,
                setSheetState: setSheetState,
              );
            },
          ),
  );
}

Widget _buildTransactionListRow({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required int index,
  required void Function(VoidCallback f) setSheetState,
}) {
  final tx = state.items[index];
  final local = tz.TZDateTime.from(tx.utc, state.loc);
  final timestampText = _AppDateLogic.formatDbTimestamp(local);
  final isSelected = state.selectedIndex == index;
  final highlightColor = Theme.of(sheetContext)
      .colorScheme
      .primary
      .withValues(alpha: 0.08);

  return InkWell(
    onTap: () {
      setSheetState(() {
        state.selectedIndex = isSelected ? null : index;
      });
    },
    child: Container(
      color: isSelected ? highlightColor : null,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 44,
            child: Text(timestampText),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 44,
            child: Text(
              tx.item,
              softWrap: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 12,
            child: Text(
              tx.qty.toString(),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTransactionActionButtons({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return Align(
    alignment: Alignment.center,
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildDeleteTransactionButton(
          sheetContext: sheetContext,
          state: state,
          setSheetState: setSheetState,
        ),
        _buildEditTransactionButton(
          sheetContext: sheetContext,
          state: state,
          setSheetState: setSheetState,
        ),
      ],
    ),
  );
}

Widget _buildDeleteTransactionButton({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return ElevatedButton.icon(
    icon: const Icon(Icons.delete),
    label: const Text('Delete transaction'),
    onPressed: state.selectedIndex == null
        ? null
        : () async {
            await _deleteSelectedTransaction(
              sheetContext: sheetContext,
              state: state,
              setSheetState: setSheetState,
            );
          },
  );
}

Future<void> _deleteSelectedTransaction({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) async {
  final idx = state.selectedIndex;
  if (idx == null || idx < 0 || idx >= state.items.length) {
    return;
  }
  final tx = state.items[idx];

  final confirmed = await _confirmTransactionDeletion(sheetContext);
  if (!confirmed) {
    return;
  }

  // Delete the transaction from the database
  try {
    await state.db.deleteTransactionById(tx.id);
  } catch (e) {
    setSheetState(() {
      state.error = 'Failed to delete transaction: $e';
    });
    return;
  }

  await _afterTransactionChanged(state);
  await state.runQuery();
  setSheetState(() {
    state.selectedIndex = null;
  });
}

Future<bool> _confirmTransactionDeletion(BuildContext sheetContext) async {
  //Ask for confirmation in a modal dialog
  final action = await showDialog<_TransactionDeleteAction>(
    context: sheetContext,
    builder: (dialogCtx) {
      return AlertDialog(
        title: const Text('Confirm deletion?'),
        content: const Text(
          'This will permanently delete the selected transaction.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(
              _TransactionDeleteAction.confirm,
            ),
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );

  // Cancel (or dismiss) → do nothing; stay on the sheet
  return action == _TransactionDeleteAction.confirm;
}

Future<void> _afterTransactionChanged(_TransactionViewerState state) async {
  // Refresh main sheet's averages and clear the undo/redo history
  await state.store.refreshFromDatabase();
  state.store.clearUndoRedo();

  //Close the "Added: ..." card on the main sheet and persist dismissal
  final main = _MainScreenState._lastMounted;
  if (main != null && main.mounted) {
    await main.dismissLastAddedBanner();
  }
  //Refresh the list in this sheet and clear the selection
}

Widget _buildEditTransactionButton({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) {
  return ElevatedButton.icon(
    icon: const Icon(Icons.edit),
    label: const Text('Edit transaction'),
    onPressed: state.selectedIndex == null
        ? null
        : () async {
            await _editSelectedTransaction(
              sheetContext: sheetContext,
              state: state,
              setSheetState: setSheetState,
            );
          },
  );
}

Future<void> _editSelectedTransaction({
  required BuildContext sheetContext,
  required _TransactionViewerState state,
  required void Function(VoidCallback f) setSheetState,
}) async {
  final idx = state.selectedIndex;
  if (idx == null || idx < 0 || idx >= state.items.length) {
    return;
  }
  final tx = state.items[idx];

  final updated = await _openTransactionEditorSheet(
    context: sheetContext,
    db: state.db,
    store: state.store,
    loc: state.loc,
    tx: tx,
  );

  if (updated == _TransactionEditorResult.updated) {
    await state.runQuery();
    setSheetState(() {
      state.selectedIndex = null;
    });
  }
}

