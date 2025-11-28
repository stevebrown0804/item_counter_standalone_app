part of 'main.dart';


// <editor-fold desc="The UI">
class _SkipSecondConfirmSetting extends StatefulWidget {
  const _SkipSecondConfirmSetting();

  @override
  State<_SkipSecondConfirmSetting> createState() =>
      _SkipSecondConfirmSettingState();
}

class _SkipSecondConfirmSettingState
    extends State<_SkipSecondConfirmSetting> {
  final _db = _Db();
  bool? _initial;
  bool _current = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _db.readSkipDeleteSecondConfirm();
    if (!mounted) return;
    setState(() {
      _initial = v;
      _current = v;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.setSkipDeleteSecondConfirm(_current);
      if (!mounted) return;
      setState(() => _initial = _current);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preference saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initial == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: SizedBox(height: 56),
      );
    }

    final changed = _initial != _current;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          CheckboxListTile(
            value: _current,
            onChanged: (v) => setState(() => _current = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
                'Skip second confirmation when deleting transactions'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: (!changed || _saving) ? null : _save,
              child: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      final s = _ViewScreenState._lastMounted;
      final active = s?._store.activeTz;
      final tzName = active?.tzName ?? 'Etc/UTC';
      final alias = active?.alias ?? DateTime.now().timeZoneName;

      var loc = tz.getLocation('Etc/UTC');
      try {
        loc = tz.getLocation(tzName);
      } catch (_) {}
      final now = tz.TZDateTime.now(loc);

      String two(int n) => n.toString().padLeft(2, '0');
      final ts = '${now.year}-${two(now.month)}-${two(now.day)}_'
          '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';

      final fileName = 'daily-pill-tracking-DB-${ts}_($alias).db';

      final dbDir = await getDatabasesPath();
      final liveDb = File(p.join(dbDir, kDbFileName));
      if (!await liveDb.exists()) {
        throw FileSystemException('Database not found', liveDb.path);
      }

      final tmpDir = p.normalize(p.join(dbDir, '..', 'files'));
      await Directory(tmpDir).create(recursive: true);
      final tmpPath = p.join(tmpDir, fileName);

      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) {
        try {
          if (tmpFile.path != liveDb.path) {
            try {
              await tmpFile.delete();
            } catch (_) {}
          }
        } catch (_) {}
      }
      await liveDb.copy(tmpPath);

      final mediaStore = MediaStore();
      await mediaStore.saveFile(
        tempFilePath: tmpFile.path,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: '',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database exported to: Downloads/$fileName'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        debugPrint('Export failed: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteOldTxDialog(BuildContext context) async {
    final db = _Db();

    final days = await db.readAveragingWindowDays();
    final count = await db.countTransactionsOlderThanDays(days);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete older transactions?'),
        content: Text(
          'This will permanently delete $count transactions older than $days days. '
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _handleDeleteOldTx(context, days);
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteOldTx(BuildContext context, int days) async {
    final db = _Db();
    final skip = await db.readSkipDeleteSecondConfirm();

    if (skip) {
      final deleted = await db.deleteOldTransactionsWithPolicy(days);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text('Deleted $deleted transactions older than $days days.')),
      );
      return;
    }

    bool skipNext = false;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: Colors.red,
            title: const Text(
              'Really delete transactions?',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Abort!'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: () async {
                          if (skipNext) {
                            await db.setSkipDeleteSecondConfirm(true);
                          }
                          final deleted =
                          await db.deleteOldTransactionsWithPolicy(days);
                          if (!context.mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Deleted $deleted transactions older than $days days.')),
                          );
                        },
                        child: const Text('Proceed'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: skipNext,
                  onChanged: (v) => setState(() => skipNext = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.white,
                  checkColor: Colors.red,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Skip this step next time.\n(This can be undone in Settings.)',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _TzRow(),
          const Divider(),
          const _WindowRow(),
          const Divider(),
          const SizedBox(height: 0),
          SizedBox(
            child: Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list_alt),
                label: const Text('View transactions'),
                onPressed: () {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final s = _ViewScreenState._lastMounted;
                    if (s != null) {
                      s._openTransactionViewer(s.context);
                    }
                  });
                },
              ),
            ),
          ),
          const Divider(),
          SizedBox(
            child: Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export database'),
                onPressed: () {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _exportDatabase(context);
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Text(
              'Danger Zone',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              onPressed: () => _showDeleteOldTxDialog(context),
              child: const Text('Delete outdated transactions'),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const _SkipSecondConfirmSetting(),
          const Divider(),
        ],
      ),
    );
  }
}

class _WindowRow extends StatefulWidget {
  const _WindowRow();
  @override
  State<_WindowRow> createState() => _WindowRowState();
}

class _WindowRowState extends State<_WindowRow> {
  final _db = _Db();
  final TextEditingController _ctrl = TextEditingController();
  bool _canSubmit = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Choose the initial date of transaction',
    );
    if (picked == null) return;

    try {
      String two(int n) => n.toString().padLeft(2, '0');
      // Local calendar date in "YYYY-MM-DD" for the backend to interpret
      // in the active time zone. Backend decides how many days the window is.
      final localDate =
          '${picked.year}-${two(picked.month)}-${two(picked.day)}';

      final days =
      await _db.computeAveragingWindowDaysFromPickedLocalDate(localDate);

      if (!mounted) return;
      setState(() {
        _ctrl.text = days.toString();
        _canSubmit = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to compute window days: $e')),
      );
    }
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    final days = int.tryParse(raw);
    if (days == null || days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a positive number of days.')),
      );
      return;
    }

    await _db.setAveragingWindowDays(days);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Averaging window set to: $days days')),
    );

    FocusScope.of(context).unfocus();
    setState(() {
      _ctrl.clear();
      _canSubmit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Averaging window, in days',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (v) =>
                          setState(() => _canSubmit = v.trim().isNotEmpty),
                      decoration: const InputDecoration(
                        hintText: 'e.g., 30',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: const Text('Pick start date'),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: const Text('Submit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TzRow extends StatefulWidget {
  const _TzRow();
  @override
  State<_TzRow> createState() => _TzRowState();
}

class _TzRowState extends State<_TzRow> {
  final _db = _Db();
  final _ctrl = TextEditingController();
  String _query = '';
  List<String> _options = const [];
  bool _loading = true;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final opts = await _db.listTzAliasStrings();
      if (!mounted) return;
      setState(() {
        _options = opts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load time zones: $e')),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;

    String displayString = raw;
    String aliasToSave;

    if (raw.contains('/')) {
      aliasToSave = raw.split('/').first.trim();
    } else {
      final rawUpper = raw.toUpperCase();
      final match = _options.firstWhere(
            (opt) => opt.split('/').any((a) => a.toUpperCase() == rawUpper),
        orElse: () => raw,
      );
      displayString = match;
      aliasToSave = match.contains('/') ? match.split('/').first.trim() : raw;
      _ctrl.text = displayString;
    }

    await _db.setActiveTzByAlias(aliasToSave);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Time zone: ($displayString) saved')),
    );

    FocusScope.of(context).unfocus();

    _ctrl.clear();
    setState(() => _canSubmit = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        title: Text('Time Zone'),
        subtitle: Text('Loading…'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Time Zone:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue tev) {
                final q = tev.text.trim().toLowerCase();
                if (q.isEmpty) return _options;
                return _options.where((s) => s.toLowerCase().contains(q));
              },
              onSelected: (value) {
                _ctrl.text = value;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                controller.text = _ctrl.text;
                controller.addListener(() {
                  _ctrl.text = controller.text;
                  final next = controller.text.trim();
                  final changed = next != _query;
                  final canSubmitNow = next.isNotEmpty;
                  if (changed || canSubmitNow != _canSubmit) {
                    setState(() {
                      _query = next;
                      _canSubmit = canSubmitNow;
                    });
                  }
                });

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: 'e.g., MT/MST/MDT or MT',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final q = _query.trim().toLowerCase();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: options.map((opt) {
                          final aliases = opt.split('/');
                          final match = q.isNotEmpty &&
                              aliases.any((a) => a.toLowerCase() == q);

                          final title = Text.rich(
                            TextSpan(
                              children: [
                                for (int i = 0; i < aliases.length; i++) ...[
                                  TextSpan(
                                    text: aliases[i],
                                    style: TextStyle(
                                      fontWeight: (q.isNotEmpty &&
                                          aliases[i].toLowerCase() == q)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (i < aliases.length - 1)
                                    const TextSpan(text: '/'),
                                ]
                              ],
                            ),
                          );

                          return ListTile(
                            dense: true,
                            selected: match,
                            title: title,
                            onTap: () => onSelected(opt),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _ViewScreen extends StatefulWidget {
  const _ViewScreen();

  @override
  State<_ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<_ViewScreen> {
  static _ViewScreenState? _lastMounted;

  final _store = _Store(_Db());
  bool _loading = true;
  String? _error;
  final _db = _Db();
  String? _tzDisplay;
  String? _lastAdded;

  Future<void> _loadActiveTzDisplay() async {
    final s = await _db.readActiveTzAliasString();
    if (!mounted) return;
    setState(() => _tzDisplay = s);
  }

  @override
  void initState() {
    super.initState();
    _lastMounted = this;
    _loadActiveTzDisplay();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await _store.load();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _lastMounted = null;
    super.dispose();
  }

  Future<void> _openAddSheet() async {
    final pills = _store.pills;
    if (pills.isEmpty) return;

    final qty = List<int>.filled(pills.length, 0);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Log pills',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pills.length,
                        separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = pills[i];
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon:
                                const Icon(Icons.keyboard_arrow_down),
                                onPressed: () => setState(() {
                                  if (qty[i] > 0) qty[i]--;
                                }),
                              ),
                              SizedBox(
                                width: 48,
                                child: TextField(
                                  key: ValueKey('qty_$i'),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                    EdgeInsets.symmetric(vertical: 6),
                                    border: OutlineInputBorder(),
                                  ),
                                  controller: TextEditingController(
                                      text: qty[i].toString()),
                                  onChanged: (s) {
                                    final v = int.tryParse(s) ?? 0;
                                    setState(() =>
                                    qty[i] = v.clamp(0, 1000000));
                                  },
                                ),
                              ),
                              IconButton(
                                icon:
                                const Icon(Icons.keyboard_arrow_up),
                                onPressed: () =>
                                    setState(() => qty[i] = qty[i] + 1),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final map = <int, int>{};
                            final parts = <String>[];
                            for (var i = 0; i < pills.length; i++) {
                              final q = qty[i];
                              if (q > 0) {
                                map[pills[i].id] = q;
                                parts.add(
                                    '${pills[i].name} x $q');
                              }
                            }
                            if (map.isEmpty) {
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              return;
                            }
                            await _store.addBatch(map);

                            if (!mounted) return;

                            final message =
                                'Added: ${parts.join(', ')}';

                            if (mounted) {
                              setState(() {
                                _lastAdded = message;
                              });
                            }

                            Navigator.of(context).pop();
                          },
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openTransactionViewer(BuildContext context) async {
    final tzName = _store.activeTz.tzName;
    tz.Location loc;
    try {
      loc = tz.getLocation(tzName);
    } catch (_) {
      loc = tz.getLocation('Etc/UTC');
    }

    _TxMode mode = _TxMode.today;
    final lastDaysCtrl = TextEditingController(text: '7');
    DateTime? startLocal;
    DateTime? endLocal;

    List<_TxRow> items = [];
    bool busy = false;
    String? error;

    Future<void> runQuery() async {
      setState(() {
        busy = true;
        error = null;
      });

      String formatLocal(DateTime dt) {
        String two(int n) => n.toString().padLeft(2, '0');
        return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
            '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
      }

      try {
        switch (mode) {
          case _TxMode.today:
            items = await _db.queryTransactionsToday();
            break;

          case _TxMode.lastNDays:
            final n = int.tryParse(lastDaysCtrl.text.trim());
            final days = (n == null || n <= 0) ? 1 : n;
            items = await _db.queryTransactionsLastNDays(days);
            break;

          case _TxMode.range:
            String? startStr;
            String? endStr;
            if (startLocal != null) {
              startStr = formatLocal(startLocal!);
            }
            if (endLocal != null) {
              endStr = formatLocal(endLocal!);
            }
            items = await _db.queryTransactionsRangeLocal(
              startLocal: startStr,
              endLocal: endStr,
            );
            break;

          case _TxMode.all:
            items = await _db.queryTransactionsAll();
            break;
        }
      } catch (ex) {
        error = ex.toString();
      } finally {
        setState(() {
          busy = false;
        });
      }
    }

    await runQuery();
    if (!mounted) return;

    showModalBottomSheet(
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
              if (mounted) setSheetState(f);
            }

            String fmtLocal(DateTime? d) {
              if (d == null) return '';
              String two(int n) => n < 10 ? '0$n' : '$n';
              return '${d.year}-${two(d.month)}-${two(d.day)} '
                  '${two(d.hour)}:${two(d.minute)}';
            }

            Widget radioRow(_TxMode m, Widget trailing) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Radio<_TxMode>(
                  value: m,
                  groupValue: mode,
                  onChanged: (v) => ss(() {
                    mode = v!;
                  }),
                ),
                const SizedBox(width: 4),
                Expanded(child: trailing),
              ],
            );

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom:
                  MediaQuery.of(ctx).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        const SizedBox(width: 4),
                        const Text('Transaction Viewer',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Refresh',
                          icon: const Icon(Icons.refresh),
                          onPressed: busy
                              ? null
                              : () async {
                            await runQuery();
                            ss(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    radioRow(_TxMode.today, const Text('Today')),
                    const Divider(),
                    radioRow(
                        _TxMode.lastNDays,
                        Row(
                          children: [
                            const Text('Last'),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: lastDaysCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    isDense: true,
                                    border:
                                    OutlineInputBorder()),
                                onTap: () => ss(() {
                                  mode = _TxMode.lastNDays;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('days'),
                          ],
                        )),
                    const Divider(),
                    radioRow(
                        _TxMode.range,
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('From'),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    readOnly: true,
                                    controller: TextEditingController(
                                        text: fmtLocal(startLocal)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border:
                                      const OutlineInputBorder(),
                                      hintText: fmtLocal(startLocal)
                                          .isEmpty
                                          ? '— select date —'
                                          : null,
                                      hintStyle: const TextStyle(
                                          color: Colors.grey),
                                    ),
                                    onTap: () => ss(() {
                                      mode = _TxMode.range;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () async {
                                    ss(() {
                                      mode = _TxMode.range;
                                    });
                                    final picked =
                                    await _pickLocalDateTime(
                                        context,
                                        loc: loc,
                                        initialLocal:
                                        startLocal);
                                    ss(() {
                                      startLocal = picked;
                                    });
                                  },
                                  child:
                                  const Text('Pick start date'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Text('to'),
                                    const SizedBox(width: 26),
                                    Expanded(
                                      child: Stack(
                                        alignment:
                                        Alignment.center,
                                        children: [
                                          TextField(
                                            readOnly: true,
                                            controller:
                                            TextEditingController(
                                                text: fmtLocal(
                                                    endLocal)),
                                            decoration:
                                            InputDecoration(
                                              isDense: true,
                                              border:
                                              const OutlineInputBorder(),
                                              hintText: fmtLocal(
                                                  startLocal)
                                                  .isEmpty
                                                  ? '— select date —'
                                                  : null,
                                              hintStyle:
                                              const TextStyle(
                                                  color: Colors
                                                      .grey),
                                            ),
                                            onTap: () => ss(() {
                                              mode =
                                                  _TxMode.range;
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () async {
                                        ss(() {
                                          mode = _TxMode.range;
                                        });
                                        final picked =
                                        await _pickLocalDateTime(
                                            context,
                                            loc: loc,
                                            initialLocal:
                                            endLocal);
                                        ss(() {
                                          endLocal = picked;
                                        });
                                      },
                                      child:
                                      const Text('Pick end date'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ],
                        )),
                    const Divider(),
                    radioRow(_TxMode.all, const Text('All')),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Apply'),
                        onPressed: busy
                            ? null
                            : () async {
                          FocusManager
                              .instance.primaryFocus
                              ?.unfocus();
                          await runQuery();
                          ss(() {});
                        },
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: TextStyle(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .error),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                          BorderRadius.circular(16),
                          border: Border.all(
                              color: Theme.of(ctx)
                                  .dividerColor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8),
                              child: Row(
                                children: const [
                                  Expanded(
                                      flex: 44,
                                      child: Text('Timestamp')),
                                  Expanded(
                                      flex: 44,
                                      child: Text('Pill name')),
                                  Expanded(
                                      flex: 12,
                                      child: Text('Qty.',
                                          textAlign:
                                          TextAlign.right)),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: busy
                                  ? const Center(
                                  child:
                                  CircularProgressIndicator())
                                  : ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (c, i) {
                                  final it = items[i];
                                  final local =
                                  tz.TZDateTime.from(
                                      it.utc, loc);
                                  String two(int n) =>
                                      n < 10
                                          ? '0$n'
                                          : '$n';
                                  final tsStr =
                                      '${local.year}-${two(local.month)}-${two(local.day)} '
                                      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';

                                  return Padding(
                                    padding:
                                    const EdgeInsets
                                        .symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                      children: [
                                        Expanded(
                                            flex: 44,
                                            child:
                                            Text(tsStr)),
                                        const SizedBox(
                                            width: 8),
                                        Expanded(
                                            flex: 44,
                                            child: Text(
                                                it.pill,
                                                softWrap:
                                                true)),
                                        const SizedBox(
                                            width: 8),
                                        Expanded(
                                          flex: 12,
                                          child: Text(
                                            it.qty
                                                .toString(),
                                            textAlign:
                                            TextAlign
                                                .right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleDays = _store.days;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pill tracker'),
            const SizedBox(height: 3),
            if (_tzDisplay != null)
              Text(
                'Time zone: $_tzDisplay',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              );
              if (!mounted) return;
              await _store.load();
              await _loadActiveTzDisplay();
              if (!mounted) return;
              setState(() {});
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_error!,
            style: const TextStyle(color: Colors.red)),
      )
          : AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          return Column(
            children: [
              const SizedBox.shrink(),
              const SizedBox(height: 4),
              if (_lastAdded != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12),
                  child: Card(
                    elevation: 0,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                                top: 2),
                            child: Icon(Icons.history),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                MediaQuery.of(
                                    context)
                                    .size
                                    .height *
                                    0.35,
                              ),
                              child:
                              SingleChildScrollView(
                                padding:
                                const EdgeInsets
                                    .only(
                                    right: 8),
                                child: SelectionArea(
                                  child: Text(
                                    _lastAdded!,
                                    softWrap: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Clear',
                            icon:
                            const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _lastAdded = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pill',
                        style: TextStyle(
                            fontWeight:
                            FontWeight.bold),
                      ),
                    ),
                    Text(
                      'Avg. ($titleDays day(s))',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _store.rows.length,
                  itemExtent: 28.0,
                  itemBuilder: (context, i) {
                    final r = _store.rows[i];
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets
                              .symmetric(
                              horizontal: 12,
                              vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.pillName,
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                r.avg
                                    .toStringAsFixed(
                                    2),
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.0),
                                textAlign:
                                TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment
                                .bottomCenter,
                            child: Container(
                              height: 1,
                              color:
                              Colors.grey.shade300,
                              margin: const EdgeInsets
                                  .symmetric(
                                  horizontal: 8),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final enabled = _store.canUndo;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.38,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: FloatingActionButton(
                      heroTag: 'undo_fab',
                      onPressed: enabled
                          ? () async => await _store.undoLast()
                          : null,
                      mini: true,
                      tooltip: 'Undo last',
                      child: const Icon(Icons.undo),
                    ),
                  ),
                ),
              );
            },
          ),
          FloatingActionButton.extended(
            heroTag: 'add_fab',
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final enabled = _store.canRedo;
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.38,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: FloatingActionButton(
                      heroTag: 'redo_fab',
                      onPressed: enabled
                          ? () async => await _store.redoLast()
                          : null,
                      mini: true,
                      tooltip: 'Redo last',
                      child: const Icon(Icons.redo),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// </editor-fold>
