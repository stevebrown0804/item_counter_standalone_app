// /ui/widgets/StackedToastHost.dart

part of '../../main.dart';

class _StackedToastEntry {
  const _StackedToastEntry({
    required this.id,
    required this.message,
  });

  final int id;
  final String message;
}

class _StackedToastController extends ChangeNotifier {
  static const int _defaultMaxVisibleToasts = 3;
  static const Duration _defaultDisplayDuration = Duration(milliseconds: 2200);

  final List<_StackedToastEntry> _entries = <_StackedToastEntry>[];
  int _nextId = 0;
  bool _disposed = false;

  List<_StackedToastEntry> get entries => List<_StackedToastEntry>.unmodifiable(_entries);

  void show(
      String message, {
        int maxVisibleToasts = _defaultMaxVisibleToasts,
        Duration displayDuration = _defaultDisplayDuration,
      }) {
    if (_disposed) {
      return;
    }

    final entry = _StackedToastEntry(
      id: _nextId,
      message: message,
    );
    _nextId++;

    _entries.add(entry);
    if (_entries.length > maxVisibleToasts) {
      _entries.removeAt(0);
    }
    notifyListeners();

    unawaited(
      Future<void>.delayed(displayDuration).then((_) {
        if (_disposed) {
          return;
        }

        final index = _entries.indexWhere((toast) => toast.id == entry.id);
        if (index < 0) {
          return;
        }

        _entries.removeAt(index);
        notifyListeners();
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _entries.clear();
    super.dispose();
  }
}

class _StackedToastHost extends StatelessWidget {
  const _StackedToastHost({
    required this.controller,
    this.lowerEdgeY,
  });

  static const double _outerPadding = 16.0;
  static const double _gap = 6.0;
  static const double _horizontalPadding = 14.0;
  static const double _verticalPadding = 10.0;
  static const double _elevation = 6.0;
  static const double _cornerRadius = 9999.0;

  final _StackedToastController controller;
  final double? lowerEdgeY;

  double _bottomOffsetForConstraints(BoxConstraints constraints) {
    final boundaryY = lowerEdgeY;
    if (boundaryY == null) {
      return _outerPadding;
    }

    final calculatedOffset = constraints.maxHeight - boundaryY;
    if (calculatedOffset < 0) {
      return 0;
    }

    return calculatedOffset;
  }

  Widget _buildToastColumn(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final entries = controller.entries;

        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final toast in entries)
              Padding(
                padding: const EdgeInsets.only(top: _gap),
                child: Align(
                  alignment: Alignment.center,
                  child: Material(
                    elevation: _elevation,
                    borderRadius: BorderRadius.circular(_cornerRadius),
                    color: Theme.of(context).colorScheme.inverseSurface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _horizontalPadding,
                        vertical: _verticalPadding,
                      ),
                      child: Text(
                        toast.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bottomOffset = _bottomOffsetForConstraints(constraints);

          return IgnorePointer(
            child: Padding(
              padding: EdgeInsets.only(
                left: _outerPadding,
                right: _outerPadding,
                bottom: bottomOffset,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: lowerEdgeY == null
                    ? SafeArea(
                  top: false,
                  child: _buildToastColumn(context),
                )
                    : _buildToastColumn(context),
              ),
            ),
          );
        },
      ),
    );
  }
}