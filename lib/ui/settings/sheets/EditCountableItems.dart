// /ui/settings/sheets/EditCountableItems.dart

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

class _EditCountableItemsSheet extends StatelessWidget {
  const _EditCountableItemsSheet();

  @override
  Widget build(BuildContext context) {
    final db = _Db();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit countable items'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<_Item>>(
        future: db.listItemsOrdered(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading items: ${snapshot.error}'),
            );
          }

          final items = snapshot.data ?? const <_Item>[];

          return LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth - 24.0;
              final idWidth = totalWidth * 0.12;
              final displayStringWidth = totalWidth * 0.42;
              final displayOrderWidth = totalWidth * 0.23;
              final showItemWidth = totalWidth * 0.23;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Table(
                    border: TableBorder.all(
                      color: Theme.of(context).dividerColor,
                    ),
                    columnWidths: <int, TableColumnWidth>{
                      0: FixedColumnWidth(idWidth),
                      1: FixedColumnWidth(displayStringWidth),
                      2: FixedColumnWidth(displayOrderWidth),
                      3: FixedColumnWidth(showItemWidth),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: <TableRow>[
                      _buildHeaderRow(),
                      ...items.map(_buildItemRow),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return const TableRow(
      children: <Widget>[
        _TableCellText(
          text: 'id',
          isHeader: true,
        ),
        _TableCellText(
          text: 'display_string',
          isHeader: true,
        ),
        _TableCellText(
          text: 'display_order',
          isHeader: true,
        ),
        _TableCellText(
          text: 'show_item',
          isHeader: true,
        ),
      ],
    );
  }

  TableRow _buildItemRow(_Item item) {
    return TableRow(
      children: <Widget>[
        _TableCellText(text: item.id.toString()),
        _TableCellText(text: item.name),
        _TableCellText(text: item.displayOrder?.toString() ?? 'NULL'),
        _TableCellText(text: item.showItem ? '1' : '0'),
      ],
    );
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText({
    required this.text,
    this.isHeader = false,
  });

  final String text;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 10.0,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isHeader
            ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
            : const TextStyle(fontSize: 13),
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