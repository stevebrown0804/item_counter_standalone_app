part of '../../../main.dart';

Future<void> doEditCountableItemsSheet({
  required BuildContext context,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return const _EditCountableItemsSheet();
    },
  );
}

class _EditableCountableItemRow {
  _EditableCountableItemRow({
    required this.id,
    required String displayString,
    required this.displayOrder,
    required this.showItem,
  }) : displayStringController = TextEditingController(text: displayString);

  final int? id;
  final TextEditingController displayStringController;
  int? displayOrder;
  bool showItem;

  factory _EditableCountableItemRow.fromItem(_Item item) {
    return _EditableCountableItemRow(
      id: item.id,
      displayString: item.name,
      displayOrder: item.displayOrder,
      showItem: item.showItem,
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
  });

  final int? id;
  final String displayString;
  final int displayOrder;
  final bool showItem;
}

class _EditCountableItemsSheet extends StatefulWidget {
  const _EditCountableItemsSheet();

  @override
  State<_EditCountableItemsSheet> createState() => _EditCountableItemsSheetState();
}

class _EditCountableItemsSheetState extends State<_EditCountableItemsSheet> {
  final _db = _Db();

  bool _loading = true;
  bool _saving = false;
  Object? _loadError;
  final List<_EditableCountableItemRow> _rows = [];

  bool get _canSubmit {
    for (final row in _rows) {
      if (row.displayStringController.text.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
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

      setState(() {
        _rows
          ..clear()
          ..addAll(loadedRows);
        _loading = false;
        _loadError = null;
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
        );
      },
    );
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
        if (main.mounted) {
          main.setState(() {});
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save countable items: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit countable items'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 0,
                horizontalMargin: 0,
                columns: const <DataColumn>[
                  DataColumn(
                    label: Text('Display string'),
                  ),
                  DataColumn(
                    label: SizedBox(
                      width: 88,
                      child: Text(
                        'Display\norder',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: SizedBox(
                      width: 65,
                      child: Text(
                        'Show?',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
                rows: _rows.map((row) {
                  return DataRow(
                    cells: <DataCell>[
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: row.displayStringController,
                            style: bodyMedium,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 88,
                          child: DropdownButtonFormField<int>(
                            value: row.displayOrder,
                            isExpanded: true,
                            style: bodyMedium,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            items: displayOrderOptions.map((value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text(
                                  value.toString(),
                                  style: bodyMedium,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                row.displayOrder = value;
                              });
                            },
                          ),
                        ),
                      ),
                      DataCell(
                        Center(
                          child: Switch(
                            value: row.showItem,
                            onChanged: (value) {
                              setState(() {
                                row.showItem = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _addRow,
              icon: const Icon(Icons.add),
              label: const Text('Add row'),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: FilledButton(
                onPressed: _canSubmit && !_saving ? _handleSubmit : null,
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditCountableItemsRow extends StatelessWidget {
  const _EditCountableItemsRow({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton(
          onPressed: onPressed,
          child: const Text('Edit countable items'),
        ),
      ),
    );
  }
}