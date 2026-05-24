// /ui/settings/EditTimeZones.dart

part of '../../main.dart';

class _EditTimeZonesRow extends StatelessWidget {
  const _EditTimeZonesRow({
    required this.onTimeZonesChanged,
    required this.onInteractionComplete,
  });

  final Future<void> Function() onTimeZonesChanged;
  final Future<void> Function(String) onInteractionComplete;

  Future<void> _openEditTimeZonesSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _EditTimeZonesSheet(
          onTimeZonesChanged: onTimeZonesChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.public),
          label: const Text('Edit time zones'),
          onPressed: () async => await _openEditTimeZonesSheet(context),
        ),
      ),
    );
  }
}

class _EditTimeZonesSheet extends StatefulWidget {
  const _EditTimeZonesSheet({
    required this.onTimeZonesChanged,
  });

  final Future<void> Function() onTimeZonesChanged;

  @override
  State<_EditTimeZonesSheet> createState() => _EditTimeZonesSheetState();
}

class _TimeZoneEditorRow {
  const _TimeZoneEditorRow({
    required this.id,
    required this.timeZone,
    required this.alias,
    required this.editable,
  });

  final int id;
  final String timeZone;
  final String alias;
  final bool editable;
}

class _EditTimeZonesSheetState extends State<_EditTimeZonesSheet> {
  static const double _tableBorderWidth = 1.0;
  static const double _horizontalSheetPadding = 16.0;
  static const double _topSheetPadding = 12.0;
  static const double _titleToTableGap = 16.0;
  static const double _tableToButtonGap = 12.0;
  static const double _buttonGap = 12.0;
  static const double _timeZoneAutocompleteMaxHeightFraction = 0.35;

  final _db = _Db();
  final TextEditingController _timeZoneAddController = TextEditingController();
  final TextEditingController _aliasEditController = TextEditingController();
  final FocusNode _timeZoneAddFocusNode = FocusNode();
  final FocusNode _aliasEditFocusNode = FocusNode();
  final MenuController _timeZoneAddMenuController = MenuController();

  bool _loading = true;
  bool _savingEdit = false;
  bool _addingRow = false;
  Object? _loadError;
  List<String> _ianaTimeZoneNames = const [];
  List<_TimeZoneEditorRow> _rows = const [];
  int? _selectedRowIndex;
  int? _editingRowId;
  String? _selectedAddTimeZone;

  bool get _isEditing => _editingRowId != null;
  bool get _isAddingOrEditing => _addingRow || _isEditing;

  List<String> get _filteredIanaTimeZoneNames {
    final typed = _timeZoneAddController.text.trim();
    if (typed.isEmpty) {
      return _ianaTimeZoneNames;
    }

    final upperTyped = typed.toUpperCase();
    return _ianaTimeZoneNames
        .where((name) => name.toUpperCase().contains(upperTyped))
        .toList();
  }

  bool get _hasSelectedEditableRow {
    final selectedRowIndex = _selectedRowIndex;
    if (selectedRowIndex == null) {
      return false;
    }

    if (selectedRowIndex < 0 || selectedRowIndex >= _rows.length) {
      throw StateError('Selected time-zone row index is out of range.');
    }

    return _rows[selectedRowIndex].editable;
  }

  @override
  void initState() {
    super.initState();
    _ianaTimeZoneNames = tz.timeZoneDatabase.locations.keys.toList()..sort();
    if (_ianaTimeZoneNames.isEmpty) {
      throw StateError('The IANA time-zone database is empty.');
    }
    unawaited(_loadRows());
  }

  @override
  void dispose() {
    _timeZoneAddFocusNode.dispose();
    _aliasEditFocusNode.dispose();
    _timeZoneAddController.dispose();
    _aliasEditController.dispose();
    super.dispose();
  }

  bool _isDefaultUtcAlias({
    required String timeZone,
    required String alias,
  }) {
    return timeZone == 'Etc/UTC' &&
        (alias == 'GMT' || alias == 'UTC' || alias == 'Z');
  }

  Future<void> _loadRows() async {
    try {
      final rows = await _db.rawQuery(
        '''
SELECT id, iana_tz_name, alias
FROM time_zone_aliases
ORDER BY iana_tz_name, alias, id
''',
      );

      final loadedRows = rows.map((row) {
        final idRaw = row['id'];
        final timeZone = row['iana_tz_name']?.toString() ?? '';
        final alias = row['alias']?.toString() ?? '';

        if (idRaw == null) {
          throw StateError('time_zone_aliases row is missing id.');
        }

        if (timeZone.isEmpty) {
          throw StateError('time_zone_aliases row is missing iana_tz_name.');
        }

        if (alias.isEmpty) {
          throw StateError('time_zone_aliases row is missing alias.');
        }

        final id = idRaw is num ? idRaw.toInt() : int.parse(idRaw.toString());

        return _TimeZoneEditorRow(
          id: id,
          timeZone: timeZone,
          alias: alias,
          editable: !_isDefaultUtcAlias(
            timeZone: timeZone,
            alias: alias,
          ),
        );
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _rows = loadedRows;
        _selectedRowIndex = null;
        _editingRowId = null;
        _addingRow = false;
        _selectedAddTimeZone = null;
        _timeZoneAddController.clear();
        _aliasEditController.clear();
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _rows = const [];
        _selectedRowIndex = null;
        _editingRowId = null;
        _addingRow = false;
        _selectedAddTimeZone = null;
        _timeZoneAddController.clear();
        _aliasEditController.clear();
        _loading = false;
        _loadError = e;
      });
    }
  }

  String _displayAliasForRow(_TimeZoneEditorRow row) {
    return row.alias == row.timeZone ? '' : row.alias;
  }

  DataCell _textCell(String text, TextStyle style) {
    return DataCell(
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          textAlign: TextAlign.left,
          style: style,
        ),
      ),
    );
  }

  DataCell _aliasEditCell() {
    return DataCell(
      TextField(
        controller: _aliasEditController,
        focusNode: _aliasEditFocusNode,
        enabled: !_savingEdit,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
        ),
      ),
    );
  }

  DataCell _timeZoneAddCell(BuildContext context) {
    final menuHeight =
        MediaQuery.sizeOf(context).height * _timeZoneAutocompleteMaxHeightFraction;

    return DataCell(
      MenuAnchor(
        controller: _timeZoneAddMenuController,
        menuChildren: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: menuHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _filteredIanaTimeZoneNames.map((timeZoneName) {
                  return MenuItemButton(
                    onPressed: () {
                      setState(() {
                        _selectedAddTimeZone = timeZoneName;
                        _timeZoneAddController.text = timeZoneName;
                        _timeZoneAddController.selection = TextSelection.collapsed(
                          offset: _timeZoneAddController.text.length,
                        );
                      });
                      _timeZoneAddMenuController.close();
                      _aliasEditFocusNode.requestFocus();
                    },
                    child: Text(timeZoneName),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        child: TextField(
          controller: _timeZoneAddController,
          focusNode: _timeZoneAddFocusNode,
          enabled: !_savingEdit,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            hintText: 'Select time zone',
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_drop_down),
              onPressed: _savingEdit
                  ? null
                  : () {
                _timeZoneAddFocusNode.requestFocus();
                if (_timeZoneAddMenuController.isOpen) {
                  _timeZoneAddMenuController.close();
                } else {
                  _timeZoneAddMenuController.open();
                }
              },
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
          ),
          onTap: () {
            if (!_timeZoneAddMenuController.isOpen) {
              _timeZoneAddMenuController.open();
            }
          },
          onChanged: (value) {
            final trimmed = value.trim();
            final matchingTimeZone = _ianaTimeZoneNames.contains(trimmed)
                ? trimmed
                : null;

            setState(() {
              _selectedAddTimeZone = matchingTimeZone;
            });

            if (!_timeZoneAddMenuController.isOpen) {
              _timeZoneAddMenuController.open();
            }
          },
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    final tableBorderColor = Theme.of(context).dividerColor;
    final disabledTextStyle = TextStyle(
      color: Theme.of(context).disabledColor,
    );
    final normalTextStyle = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final tableMinWidth = MediaQuery.sizeOf(context).width - (_horizontalSheetPadding * 2);
    final textLineHeight = normalTextStyle.fontSize == null
        ? kMinInteractiveDimension * 0.35
        : normalTextStyle.fontSize! * (normalTextStyle.height ?? 1.0);
    final tableRowHeight = textLineHeight + 16.0;
    final tableHeadingRowHeight = textLineHeight + 18.0;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Text(
          'Failed to load time zones: $_loadError',
          textAlign: TextAlign.center,
        ),
      );
    }

    final tableRows = List<DataRow>.generate(
      _rows.length,
          (index) {
        final row = _rows[index];
        final rowTextStyle = row.editable ? normalTextStyle : disabledTextStyle;
        final rowIsBeingEdited = _editingRowId == row.id;

        return DataRow(
          selected: _selectedRowIndex == index,
          onSelectChanged: row.editable && !_isAddingOrEditing
              ? (selected) {
            setState(() {
              _selectedRowIndex = selected == true ? index : null;
            });
          }
              : null,
          cells: <DataCell>[
            _textCell(row.timeZone, rowTextStyle),
            rowIsBeingEdited
                ? _aliasEditCell()
                : _textCell(_displayAliasForRow(row), rowTextStyle),
          ],
        );
      },
    );

    if (_addingRow) {
      tableRows.add(
        DataRow(
          cells: <DataCell>[
            _timeZoneAddCell(context),
            _aliasEditCell(),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: tableMinWidth,
            ),
            child: DataTable(
              showCheckboxColumn: false,
              dataRowMinHeight: tableRowHeight,
              dataRowMaxHeight: tableRowHeight,
              headingRowHeight: tableHeadingRowHeight,
              border: TableBorder(
                top: BorderSide(
                  color: tableBorderColor,
                  width: _tableBorderWidth,
                ),
                right: BorderSide(
                  color: tableBorderColor,
                  width: _tableBorderWidth,
                ),
                bottom: BorderSide(
                  color: tableBorderColor,
                  width: _tableBorderWidth,
                ),
                left: BorderSide(
                  color: tableBorderColor,
                  width: _tableBorderWidth,
                ),
                horizontalInside: BorderSide(
                  color: tableBorderColor,
                  width: _tableBorderWidth,
                ),
                verticalInside: BorderSide(
                  color: tableBorderColor,
                  width: _tableBorderWidth,
                ),
              ),
              columns: const <DataColumn>[
                DataColumn(
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Time zone',
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                DataColumn(
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Alias (opt.)',
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ],
              rows: tableRows,
            ),
          ),
        ),
      ),
    );
  }

  void _beginAddingRow() {
    setState(() {
      _addingRow = true;
      _selectedRowIndex = null;
      _editingRowId = null;
      _selectedAddTimeZone = null;
      _timeZoneAddController.clear();
      _aliasEditController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _timeZoneAddFocusNode.requestFocus();
      _timeZoneAddMenuController.open();
    });
  }

  void _beginEditingSelectedRow() {
    final selectedRowIndex = _selectedRowIndex;
    if (selectedRowIndex == null) {
      throw StateError('Edit was requested with no selected time-zone row.');
    }

    if (selectedRowIndex < 0 || selectedRowIndex >= _rows.length) {
      throw StateError('Selected time-zone row index is out of range.');
    }

    final selectedRow = _rows[selectedRowIndex];
    if (!selectedRow.editable) {
      throw StateError('Default time-zone aliases cannot be edited.');
    }

    setState(() {
      _editingRowId = selectedRow.id;
      _aliasEditController.text = _displayAliasForRow(selectedRow);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _aliasEditFocusNode.requestFocus();
      _aliasEditController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _aliasEditController.text.length,
      );
    });
  }

  void _cancelAddingOrEditing() {
    setState(() {
      _addingRow = false;
      _editingRowId = null;
      _selectedAddTimeZone = null;
      _timeZoneAddController.clear();
      _aliasEditController.clear();
    });
  }

  Future<void> _saveNewRow() async {
    final selectedTimeZone = _selectedAddTimeZone;
    if (selectedTimeZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid time zone.')),
      );
      return;
    }

    final editedAlias = _aliasEditController.text.trim();
    final aliasToSave = editedAlias.isEmpty ? selectedTimeZone : editedAlias;

    setState(() {
      _savingEdit = true;
    });

    try {
      final db = await _db.open();

      await db.insert(
        'time_zone_aliases',
        {
          'iana_tz_name': selectedTimeZone,
          'alias': aliasToSave,
        },
      );

      await _loadRows();
      await widget.onTimeZonesChanged();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add time-zone alias: $e')),
      );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingEdit = false;
      });
    }
  }

  Future<void> _saveEditedAlias() async {
    final editingRowId = _editingRowId;
    if (editingRowId == null) {
      throw StateError('Save was requested with no time-zone row being edited.');
    }

    final matchingRows = _rows.where((row) => row.id == editingRowId).toList();
    if (matchingRows.length != 1) {
      throw StateError('Expected exactly one edited time-zone row, found ${matchingRows.length}.');
    }

    final editingRow = matchingRows.single;
    if (!editingRow.editable) {
      throw StateError('Default time-zone aliases cannot be edited.');
    }

    final editedAlias = _aliasEditController.text.trim();
    final aliasToSave = editedAlias.isEmpty ? editingRow.timeZone : editedAlias;

    setState(() {
      _savingEdit = true;
    });

    try {
      final db = await _db.open();

      final updated = await db.update(
        'time_zone_aliases',
        {'alias': aliasToSave},
        where: 'id = ?',
        whereArgs: [editingRow.id],
      );

      if (updated != 1) {
        throw StateError(
          'Expected to update exactly one time_zone_aliases row for id ${editingRow.id}, but updated $updated.',
        );
      }

      await _loadRows();
      await widget.onTimeZonesChanged();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save time-zone alias: $e')),
      );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingEdit = false;
      });
    }
  }

  Future<void> _saveAddingOrEditing() async {
    if (_addingRow) {
      await _saveNewRow();
      return;
    }

    await _saveEditedAlias();
  }

  Future<void> _deleteSelectedRow() async {
    final selectedRowIndex = _selectedRowIndex;
    if (selectedRowIndex == null) {
      throw StateError('Delete was requested with no selected time-zone row.');
    }

    if (selectedRowIndex < 0 || selectedRowIndex >= _rows.length) {
      throw StateError('Selected time-zone row index is out of range.');
    }

    final selectedRow = _rows[selectedRowIndex];
    if (!selectedRow.editable) {
      throw StateError('Default time-zone aliases cannot be deleted.');
    }

    final db = await _db.open();

    final activeRows = await db.rawQuery(
      '''
SELECT value
FROM settings
WHERE key = 'time_zone_id'
LIMIT 1
''',
    );

    final activeTimeZoneIdRaw =
    activeRows.isEmpty ? null : activeRows.first['value'];
    final activeTimeZoneId = activeTimeZoneIdRaw == null
        ? null
        : int.tryParse(activeTimeZoneIdRaw.toString());

    final deletingActiveAlias = activeTimeZoneId == selectedRow.id;

    if (deletingActiveAlias) {
      final replacementRows = await db.rawQuery(
        '''
SELECT id
FROM time_zone_aliases
WHERE iana_tz_name = ?1
  AND id != ?2
ORDER BY alias, id
LIMIT 1
''',
        [selectedRow.timeZone, selectedRow.id],
      );

      int? replacementId;
      if (replacementRows.isNotEmpty) {
        final replacementIdRaw = replacementRows.first['id'];
        if (replacementIdRaw == null) {
          throw StateError('Replacement time-zone alias row is missing id.');
        }

        replacementId = replacementIdRaw is num
            ? replacementIdRaw.toInt()
            : int.parse(replacementIdRaw.toString());
      } else {
        final utcRows = await db.rawQuery(
          '''
SELECT id
FROM time_zone_aliases
WHERE iana_tz_name = 'Etc/UTC'
  AND alias = 'UTC'
LIMIT 1
''',
        );

        if (utcRows.isEmpty || utcRows.first['id'] == null) {
          throw StateError('UTC fallback time-zone alias is missing.');
        }

        final utcIdRaw = utcRows.first['id'];
        replacementId = utcIdRaw is num
            ? utcIdRaw.toInt()
            : int.parse(utcIdRaw.toString());
      }

      final updated = await db.update(
        'settings',
        {'value': replacementId.toString()},
        where: 'key = ?',
        whereArgs: ['time_zone_id'],
      );

      if (updated == 0) {
        await db.insert(
          'settings',
          {
            'key': 'time_zone_id',
            'value': replacementId.toString(),
          },
        );
      }
    }

    final deleted = await db.delete(
      'time_zone_aliases',
      where: 'id = ?',
      whereArgs: [selectedRow.id],
    );

    if (deleted != 1) {
      throw StateError(
        'Expected to delete exactly one time_zone_aliases row for id ${selectedRow.id}, but deleted $deleted.',
      );
    }

    await _loadRows();
    await widget.onTimeZonesChanged();
  }

  Widget _buildActionButtons() {
    if (_isAddingOrEditing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(
            onPressed: _savingEdit ? null : () async => await _saveAddingOrEditing(),
            child: const Text('Save'),
          ),
          const SizedBox(width: _buttonGap),
          FilledButton(
            onPressed: _savingEdit ? null : _cancelAddingOrEditing,
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton(
          onPressed: _beginAddingRow,
          child: const Text('Add'),
        ),
        const SizedBox(width: _buttonGap),
        FilledButton(
          onPressed: _hasSelectedEditableRow ? _beginEditingSelectedRow : null,
          child: const Text('Edit'),
        ),
        const SizedBox(width: _buttonGap),
        FilledButton(
          onPressed: _hasSelectedEditableRow
              ? () async => await _deleteSelectedRow()
              : null,
          child: const Text('Delete'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 1.0,
        child: Padding(
          padding: EdgeInsets.only(
            left: _horizontalSheetPadding,
            right: _horizontalSheetPadding,
            top: _topSheetPadding,
            bottom: _bottomSheetBottomPadding(
              context,
              _standardBottomSheetBottomPadding,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit time zones',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: kMinInteractiveDimension),
                ],
              ),
              const SizedBox(height: _titleToTableGap),
              Flexible(
                fit: FlexFit.loose,
                child: _buildTable(context),
              ),
              const SizedBox(height: _tableToButtonGap),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}