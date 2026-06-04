// ui/settings/sheets/EditCountableItems.dart

part of '../../../main.dart';

Future<void> _doEditCountableItemsSheet({
  required BuildContext context,
  required _Db db,
  required Future<void> Function(String) onInteractionComplete,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _EditCountableItemsSheet(
        db: db,
        onInteractionComplete: onInteractionComplete,
      );
    },
  );
}

class _EditableCountableItemRow {
  _EditableCountableItemRow({
    required this.id,
    required String displayString,
    required this.displayOrder,
    required this.showItem,
    required this.isHeader,
  }) : displayStringController = TextEditingController(text: displayString);

  final int? id;
  final TextEditingController displayStringController;
  int? displayOrder;
  bool showItem;
  bool isHeader;

  factory _EditableCountableItemRow.fromItem(_Item item) {
    return _EditableCountableItemRow(
      id: item.id,
      displayString: item.name,
      displayOrder: item.displayOrder,
      showItem: item.showItem,
      isHeader: item.isHeader,
    );
  }

  factory _EditableCountableItemRow.empty({
    required int defaultDisplayOrder,
  }) {
    return _EditableCountableItemRow(
      id: null,
      displayString: '',
      displayOrder: defaultDisplayOrder,
      showItem: true,
      isHeader: false,
    );
  }

  void dispose() {
    displayStringController.dispose();
  }
}

class _SubmittedCountableItemRow {
  const _SubmittedCountableItemRow({
    required this.id,
    required this.displayString,
    required this.displayOrder,
    required this.showItem,
    required this.isHeader,
  });

  final int? id;
  final String displayString;
  final int displayOrder;
  final bool showItem;
  final bool isHeader;
}

class _EditCountableItemsSheet extends StatefulWidget {
  const _EditCountableItemsSheet({
    required this.db,
    required this.onInteractionComplete,
  });

  final _Db db;
  final Future<void> Function(String) onInteractionComplete;

  @override
  State<_EditCountableItemsSheet> createState() => _EditCountableItemsSheetState();
}

class _EditCountableItemsSheetState extends State<_EditCountableItemsSheet> {
  _Db get _db => widget.db;

  bool _loading = true;
  bool _saving = false;
  Object? _loadError;
  final List<_EditableCountableItemRow> _rows = [];
  List<_SubmittedCountableItemRow> _loadedSubmittedRows = const [];

  Set<int> get _duplicateDisplayOrders {
    final counts = <int, int>{};

    for (final row in _rows) {
      final value = row.displayOrder;
      if (value == null) {
        continue;
      }
      counts[value] = (counts[value] ?? 0) + 1;
    }

    final duplicates = <int>{};
    counts.forEach((value, count) {
      if (count > 1) {
        duplicates.add(value);
      }
    });
    return duplicates;
  }

  bool get _hasDuplicateDisplayOrders => _duplicateDisplayOrders.isNotEmpty;

  bool get _canSubmit {
    if (_hasDuplicateDisplayOrders) {
      return false;
    }

    final currentRows = _buildSubmittedRows();
    if (currentRows.isEmpty) {
      return false;
    }

    return !_submittedRowsMatch(_loadedSubmittedRows, currentRows);
  }

  Future<void> _handleDeleteRow(_EditableCountableItemRow row) async {
    if (_saving) {
      return;
    }

    setState(() {
      _rows.remove(row);

      final sortedRows = List<_EditableCountableItemRow>.from(_rows)
        ..sort((a, b) {
          final aOrder = a.displayOrder ?? 1 << 30;
          final bOrder = b.displayOrder ?? 1 << 30;

          final orderCompare = aOrder.compareTo(bOrder);
          if (orderCompare != 0) {
            return orderCompare;
          }

          return _rows.indexOf(a).compareTo(_rows.indexOf(b));
        });

      for (var i = 0; i < sortedRows.length; i++) {
        sortedRows[i].displayOrder = i + 1;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      row.dispose();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _db.listItemsOrdered();

      final loadedRows = items
          .map(_EditableCountableItemRow.fromItem)
          .toList();

      if (loadedRows.isEmpty) {
        loadedRows.add(
          _EditableCountableItemRow.empty(defaultDisplayOrder: 1),
        );
      }

      if (!mounted) {
        for (final row in loadedRows) {
          row.dispose();
        }
        return;
      }

      final oldRows = List<_EditableCountableItemRow>.from(_rows);

      setState(() {
        _rows
          ..clear()
          ..addAll(loadedRows);
        _loadedSubmittedRows = _snapshotSubmittedRows();
        _loading = false;
        _loadError = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final row in oldRows) {
          row.dispose();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  void _addRow() {
    setState(() {
      _rows.add(
        _EditableCountableItemRow.empty(
          defaultDisplayOrder: _rows.length + 1,
        ),
      );
    });
  }

  void _setDisplayOrderAndCollapse(
      _EditableCountableItemRow movedRow,
      int? requestedDisplayOrder,
      ) {
    if (requestedDisplayOrder == null) {
      return;
    }

    final oldDisplayOrder = movedRow.displayOrder;
    if (oldDisplayOrder == null) {
      movedRow.displayOrder = requestedDisplayOrder;
      return;
    }

    final newDisplayOrder = requestedDisplayOrder.clamp(1, _rows.length);
    if (oldDisplayOrder == newDisplayOrder) {
      return;
    }

    for (final row in _rows) {
      if (identical(row, movedRow) || row.displayOrder == null) {
        continue;
      }

      final rowDisplayOrder = row.displayOrder!;

      if (oldDisplayOrder < newDisplayOrder &&
          rowDisplayOrder > oldDisplayOrder &&
          rowDisplayOrder <= newDisplayOrder) {
        row.displayOrder = rowDisplayOrder - 1;
      } else if (oldDisplayOrder > newDisplayOrder &&
          rowDisplayOrder >= newDisplayOrder &&
          rowDisplayOrder < oldDisplayOrder) {
        row.displayOrder = rowDisplayOrder + 1;
      }
    }

    movedRow.displayOrder = newDisplayOrder;
  }

  List<int> get _displayOrderOptions {
    return List<int>.generate(_rows.length, (i) => i + 1);
  }

  List<_SubmittedCountableItemRow> _buildSubmittedRows() {
    final keptRows = <({
    int originalIndex,
    int? id,
    String displayString,
    int? displayOrder,
    bool showItem,
    bool isHeader,
    })>[];

    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final displayString = row.displayStringController.text.trim();
      if (displayString.isEmpty) {
        continue;
      }

      keptRows.add((
      originalIndex: i,
      id: row.id,
      displayString: displayString,
      displayOrder: row.displayOrder,
      showItem: row.showItem,
      isHeader: row.isHeader,
      ));
    }

    keptRows.sort((a, b) {
      final aOrder = a.displayOrder ?? 1 << 30;
      final bOrder = b.displayOrder ?? 1 << 30;

      final orderCompare = aOrder.compareTo(bOrder);
      if (orderCompare != 0) {
        return orderCompare;
      }

      return a.originalIndex.compareTo(b.originalIndex);
    });

    return List<_SubmittedCountableItemRow>.generate(
      keptRows.length,
          (i) {
        final row = keptRows[i];
        return _SubmittedCountableItemRow(
          id: row.id,
          displayString: row.displayString,
          displayOrder: i + 1,
          showItem: row.showItem,
          isHeader: row.isHeader,
        );
      },
    );
  }

  bool _submittedRowsMatch(
      List<_SubmittedCountableItemRow> left,
      List<_SubmittedCountableItemRow> right,
      ) {
    if (left.length != right.length) {
      return false;
    }

    for (var i = 0; i < left.length; i++) {
      final a = left[i];
      final b = right[i];

      if (a.id != b.id ||
          a.displayString != b.displayString ||
          a.displayOrder != b.displayOrder ||
          a.showItem != b.showItem ||
          a.isHeader != b.isHeader) {
        return false;
      }
    }

    return true;
  }

  List<_SubmittedCountableItemRow> _snapshotSubmittedRows() {
    return List<_SubmittedCountableItemRow>.unmodifiable(_buildSubmittedRows());
  }

  Future<void> _handleSubmit() async {
    final submittedRows = _buildSubmittedRows();
    if (submittedRows.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _db.saveCountableItems(submittedRows);

      final main = _MainScreenState._lastMounted;
      if (main != null && main.mounted) {
        await main._store.refreshFromDatabase();
        await main._loadActiveTzDisplay();
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onInteractionComplete('Countable items saved.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save countable items: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const displayStringColumnFraction = 0.44;
    const displayOrderColumnFraction = 0.18;
    const showItemColumnFraction = 0.15;
    const sectionHeaderColumnFraction = 0.17;
    const deleteColumnFraction = 0.06;
    const editableFieldHeight = 42.0;
    const screenPadding = 12.0;
    const submitButtonTopGap = 20.0;
    const addRowButtonTopGap = 12.0;
    const headerBottomGap = 10.0;
    const rowVerticalGap = 8.0;
    const fieldHorizontalPadding = 12.0;
    const dropdownHorizontalPadding = 12.0;
    const fieldBorderRadius = 4.0;

    final bodyMedium = Theme.of(context).textTheme.bodyMedium;
    final duplicateDisplayOrders = _duplicateDisplayOrders;
    final outlineColor = Theme.of(context).colorScheme.outline;
    final errorStyle = bodyMedium?.copyWith(color: Colors.red) ??
        const TextStyle(color: Colors.red);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit countable items'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit countable items'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error loading items: $_loadError'),
        ),
      );
    }

    final displayOrderOptions = _displayOrderOptions;
    final bottomSystemPadding = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardPadding = MediaQuery.viewInsetsOf(context).bottom;
    final bottomObstructionPadding =
    keyboardPadding > 0 ? keyboardPadding : bottomSystemPadding;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit countable items'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableRowWidth =
              constraints.maxWidth - screenPadding - screenPadding;

          if (availableRowWidth <= 0) {
            throw StateError(
              'Edit countable items did not receive a positive layout width.',
            );
          }

          final displayStringColumnWidth =
              availableRowWidth * displayStringColumnFraction;
          final displayOrderColumnWidth =
              availableRowWidth * displayOrderColumnFraction;
          final showItemColumnWidth =
              availableRowWidth * showItemColumnFraction;
          final sectionHeaderColumnWidth =
              availableRowWidth * sectionHeaderColumnFraction;
          final deleteColumnWidth =
              availableRowWidth * deleteColumnFraction;

          BoxDecoration fieldBoxDecoration() {
            return BoxDecoration(
              border: Border.all(
                color: outlineColor,
              ),
              borderRadius: BorderRadius.circular(fieldBorderRadius),
            );
          }

          Widget headerText(String text, double width, TextAlign textAlign) {
            return SizedBox(
              width: width,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: textAlign == TextAlign.left
                    ? Alignment.centerLeft
                    : Alignment.center,
                child: Text(
                  text,
                  textAlign: textAlign,
                  style: bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }

          Widget displayStringField(_EditableCountableItemRow row) {
            return Container(
              width: displayStringColumnWidth,
              height: editableFieldHeight,
              decoration: fieldBoxDecoration(),
              padding: const EdgeInsets.symmetric(
                horizontal: fieldHorizontalPadding,
              ),
              alignment: Alignment.center,
              child: TextField(
                key: ValueKey('display_string_${row.id ?? row.displayOrder}_${identityHashCode(row)}'),
                controller: row.displayStringController,
                style: bodyMedium,
                maxLines: 1,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            );
          }

          Widget displayOrderDropdown(
              _EditableCountableItemRow row,
              bool isDuplicate,
              ) {
            return Container(
              width: displayOrderColumnWidth,
              height: editableFieldHeight,
              decoration: fieldBoxDecoration(),
              padding: const EdgeInsets.symmetric(
                horizontal: dropdownHorizontalPadding,
              ),
              alignment: Alignment.center,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  key: ValueKey('display_order_${row.id ?? row.displayOrder}_${identityHashCode(row)}'),
                  value: row.displayOrder,
                  isExpanded: true,
                  style: isDuplicate ? errorStyle : bodyMedium,
                  items: displayOrderOptions.map((value) {
                    final itemIsDuplicate =
                    duplicateDisplayOrders.contains(value);

                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(
                        value.toString(),
                        style: itemIsDuplicate ? errorStyle : bodyMedium,
                      ),
                    );
                  }).toList(),
                  selectedItemBuilder: (context) {
                    return displayOrderOptions.map((value) {
                      final itemIsDuplicate =
                      duplicateDisplayOrders.contains(value);

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value.toString(),
                          style: itemIsDuplicate ? errorStyle : bodyMedium,
                        ),
                      );
                    }).toList();
                  },
                  onChanged: (value) {
                    setState(() {
                      _setDisplayOrderAndCollapse(row, value);
                    });
                  },
                ),
              ),
            );
          }

          Widget sectionHeaderCheckbox(_EditableCountableItemRow row) {
            return SizedBox(
              width: sectionHeaderColumnWidth,
              height: editableFieldHeight,
              child: Center(
                child: Checkbox(
                  key: ValueKey('section_header_${row.id ?? row.displayOrder}_${identityHashCode(row)}'),
                  value: row.isHeader,
                  onChanged: (value) {
                    setState(() {
                      row.isHeader = value ?? false;
                    });
                  },
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: screenPadding,
              right: screenPadding,
              top: screenPadding,
              bottom: screenPadding + bottomObstructionPadding,
            ),
            child: Column(
              children: [
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        headerText('Display string', displayStringColumnWidth, TextAlign.left),
                        headerText('Display\norder', displayOrderColumnWidth, TextAlign.center),
                        headerText('Show?', showItemColumnWidth, TextAlign.center),
                        SizedBox(width: sectionHeaderColumnWidth + deleteColumnWidth, child: FittedBox(fit: BoxFit.scaleDown, child: Text('Header', style: bodyMedium?.copyWith(fontWeight: FontWeight.bold)))),
                        const SizedBox.shrink(),
                      ],
                    ),
                    const SizedBox(height: headerBottomGap),
                    ..._rows.map((row) {
                      final isDuplicate = row.displayOrder != null &&
                          duplicateDisplayOrders.contains(row.displayOrder);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: rowVerticalGap),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            displayStringField(row),
                            displayOrderDropdown(row, isDuplicate),
                            SizedBox(
                              width: showItemColumnWidth,
                              height: editableFieldHeight,
                              child: Center(
                                child: Switch(
                                  key: ValueKey('show_item_${row.id ?? row.displayOrder}_${identityHashCode(row)}'),
                                  value: row.showItem,
                                  onChanged: (value) {
                                    setState(() {
                                      row.showItem = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                            sectionHeaderCheckbox(row),
                            SizedBox(
                              width: deleteColumnWidth,
                              height: editableFieldHeight,
                              child: Center(
                                child: GestureDetector(
                                  onTap: _saving ? null : () => _handleDeleteRow(row),
                                  child: Text(
                                    '[x]',
                                    textAlign: TextAlign.center,
                                    style: bodyMedium?.copyWith(color: Colors.red) ??
                                        const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: addRowButtonTopGap),
                FilledButton.icon(
                  onPressed: _saving ? null : _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add row'),
                ),
                const SizedBox(height: submitButtonTopGap),
                Align(
                  alignment: Alignment.center,
                  child: FilledButton(
                    onPressed: _canSubmit && !_saving ? _handleSubmit : null,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditCountableItemsRow extends StatelessWidget {
  const _EditCountableItemsRow({
    required this.db,
    required this.onInteractionComplete,
  });

  final _Db db;
  final Future<void> Function(String) onInteractionComplete;

  Future<void> _openEditCountableItemsSheet(BuildContext context) async {
    await _doEditCountableItemsSheet(
      context: context,
      db: db,
      onInteractionComplete: onInteractionComplete,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton(
          onPressed: () async => await _openEditCountableItemsSheet(context),
          child: const Text('Edit countable items'),
        ),
      ),
    );
  }
}

