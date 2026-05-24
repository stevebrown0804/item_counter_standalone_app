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

  final _db = _Db();

  bool _loading = true;
  Object? _loadError;
  List<_TimeZoneEditorRow> _rows = const [];
  int? _selectedRowIndex;

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
    unawaited(_loadRows());
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
        _loading = false;
        _loadError = e;
      });
    }
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
              rows: List<DataRow>.generate(
                _rows.length,
                    (index) {
                  final row = _rows[index];
                  final rowTextStyle = row.editable ? normalTextStyle : disabledTextStyle;

                  return DataRow(
                    selected: _selectedRowIndex == index,
                    onSelectChanged: row.editable
                        ? (selected) {
                      setState(() {
                        _selectedRowIndex = selected == true ? index : null;
                      });
                    }
                        : null,
                    cells: <DataCell>[
                      _textCell(row.timeZone, rowTextStyle),
                      _textCell(row.alias, rowTextStyle),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Add'),
                  ),
                  const SizedBox(width: _buttonGap),
                  FilledButton(
                    onPressed: _hasSelectedEditableRow ? () {} : null,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}