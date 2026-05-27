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

class _AddTimeZoneDialogResult {
  const _AddTimeZoneDialogResult({
    required this.timeZone,
    required this.alias,
  });

  final String timeZone;
  final String alias;
}

class _AddTimeZoneDialog extends StatefulWidget {
  const _AddTimeZoneDialog({
    required this.ianaTimeZoneNames,
  });

  final List<String> ianaTimeZoneNames;

  @override
  State<_AddTimeZoneDialog> createState() => _AddTimeZoneDialogState();
}

class _AddTimeZoneDialogState extends State<_AddTimeZoneDialog> {
  static const double _dialogWidthFraction = 0.85;
  static const double _filteredListHeightFraction = 0.30;
  static const double _fieldGap = 16.0;

  final TextEditingController _timeZoneController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final FocusNode _timeZoneFocusNode = FocusNode();
  final FocusNode _aliasFocusNode = FocusNode();

  String? _selectedTimeZone;

  List<String> get _filteredTimeZones {
    final typed = _timeZoneController.text.trim();
    if (typed.isEmpty) {
      return widget.ianaTimeZoneNames;
    }

    final upperTyped = typed.toUpperCase();
    return widget.ianaTimeZoneNames
        .where((name) => name.toUpperCase().contains(upperTyped))
        .toList();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _timeZoneFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timeZoneFocusNode.dispose();
    _aliasFocusNode.dispose();
    _timeZoneController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  void _handleTimeZoneTextChanged(String value) {
    final trimmed = value.trim();
    final matchingTimeZone = widget.ianaTimeZoneNames.contains(trimmed)
        ? trimmed
        : null;

    setState(() {
      _selectedTimeZone = matchingTimeZone;
    });
  }

  void _selectTimeZone(String timeZoneName) {
    setState(() {
      _selectedTimeZone = timeZoneName;
      _timeZoneController.text = timeZoneName;
      _timeZoneController.selection = TextSelection.collapsed(
        offset: _timeZoneController.text.length,
      );
    });

    _aliasFocusNode.requestFocus();
  }

  void _save() {
    final selectedTimeZone = _selectedTimeZone;
    if (selectedTimeZone == null) {
      throw StateError('Save was requested without a valid selected time zone.');
    }

    final aliasText = _aliasController.text.trim();

    Navigator.of(context).pop(
      _AddTimeZoneDialogResult(
        timeZone: selectedTimeZone,
        alias: aliasText.isEmpty ? selectedTimeZone : aliasText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = mediaQuery.size.width * _dialogWidthFraction;
    final availableHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    final filteredListMaxHeight = availableHeight * _filteredListHeightFraction;
    final filteredTimeZones = _filteredTimeZones;

    return AlertDialog(
      title: const Text('Add time zone'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _timeZoneController,
                focusNode: _timeZoneFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Time zone',
                  border: OutlineInputBorder(),
                ),
                onChanged: _handleTimeZoneTextChanged,
              ),
              const SizedBox(height: _fieldGap),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: filteredListMaxHeight,
                ),
                child: Material(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredTimeZones.length,
                    itemBuilder: (context, index) {
                      final timeZoneName = filteredTimeZones[index];

                      return ListTile(
                        dense: true,
                        title: Text(timeZoneName),
                        onTap: () => _selectTimeZone(timeZoneName),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: _fieldGap),
              TextField(
                controller: _aliasController,
                focusNode: _aliasFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Alias (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedTimeZone == null ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditTimeZonesSheetState extends State<_EditTimeZonesSheet> {
  static const double _tableBorderWidth = 1.0;
  static const double _horizontalSheetPadding = 16.0;
  static const double _topSheetPadding = 12.0;
  static const double _titleToTableGap = 16.0;
  static const double _tableToButtonGap = 12.0;
  static const double _buttonGap = 12.0;

  final _db = _Db();
  final TextEditingController _aliasEditController = TextEditingController();
  final FocusNode _aliasEditFocusNode = FocusNode();

  bool _loading = true;
  bool _savingEdit = false;
  Object? _loadError;
  List<String> _ianaTimeZoneNames = const [];
  List<_TimeZoneEditorRow> _rows = const [];
  int? _selectedRowIndex;
  int? _editingRowId;

  bool get _isEditing => _editingRowId != null;

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
    _aliasEditFocusNode.dispose();
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
          onSelectChanged: row.editable && !_isEditing
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

  Future<void> _openAddTimeZoneDialog() async {
    final result = await showDialog<_AddTimeZoneDialogResult>(
      context: context,
      builder: (context) {
        return _AddTimeZoneDialog(
          ianaTimeZoneNames: _ianaTimeZoneNames,
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      final db = await _db.open();

      await db.insert(
        'time_zone_aliases',
        {
          'iana_tz_name': result.timeZone,
          'alias': result.alias,
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
    }
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

  void _cancelEditing() {
    setState(() {
      _editingRowId = null;
      _aliasEditController.clear();
    });
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
    if (_isEditing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(
            onPressed: _savingEdit ? null : () async => await _saveEditedAlias(),
            child: const Text('Save'),
          ),
          const SizedBox(width: _buttonGap),
          FilledButton(
            onPressed: _savingEdit ? null : _cancelEditing,
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton(
          onPressed: () async => await _openAddTimeZoneDialog(),
          child: const Text('Add'),
        ),
        const SizedBox(width: _buttonGap),
        FilledButton(
          onPressed: _hasSelectedEditableRow ? _beginEditingSelectedRow : null,
          child: const Text('Edit alias'),
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