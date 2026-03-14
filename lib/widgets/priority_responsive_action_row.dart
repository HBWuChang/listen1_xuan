import 'package:flutter/material.dart';

class PriorityResponsiveActionRow extends StatefulWidget {
  const PriorityResponsiveActionRow({
    super.key,
    required this.children,
    required this.hidePriority,
    this.mainAxisSize = MainAxisSize.min,
    this.minVisibleCount = 1,
  });

  final List<Widget> children;
  final List<int> hidePriority;
  final MainAxisSize mainAxisSize;
  final int minVisibleCount;

  @override
  State<PriorityResponsiveActionRow> createState() =>
      _PriorityResponsiveActionRowState();
}

class _PriorityResponsiveActionRowState
    extends State<PriorityResponsiveActionRow> {
  List<GlobalKey> _measureKeys = [];
  List<double>? _measuredWidths;
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _syncMeasureKeys();
  }

  @override
  void didUpdateWidget(covariant PriorityResponsiveActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _syncMeasureKeys();
      _measuredWidths = null;
    }
  }

  void _syncMeasureKeys() {
    _measureKeys = List.generate(widget.children.length, (_) => GlobalKey());
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;

      final widths = <double>[];
      for (final key in _measureKeys) {
        final width = key.currentContext?.size?.width;
        if (width == null || width <= 0) {
          return;
        }
        widths.add(width);
      }

      final changed =
          _measuredWidths == null ||
          _measuredWidths!.length != widths.length ||
          widths.asMap().entries.any(
            (entry) => (_measuredWidths![entry.key] - entry.value).abs() > 0.5,
          );

      if (changed) {
        setState(() {
          _measuredWidths = widths;
        });
      }
    });
  }

  List<int> _buildVisibleIndexes(double maxWidth) {
    final totalChildren = widget.children.length;
    final minVisible = widget.minVisibleCount.clamp(0, totalChildren).toInt();

    if (_measuredWidths == null || _measuredWidths!.length != totalChildren) {
      final estimatedVisible = (maxWidth / kMinInteractiveDimension)
          .floor()
          .clamp(minVisible, totalChildren)
          .toInt();
      final hideCount = totalChildren - estimatedVisible;
      final hidden = widget.hidePriority.take(hideCount).toSet();
      return List<int>.generate(
        totalChildren,
        (index) => index,
      ).where((index) => !hidden.contains(index)).toList();
    }

    final widths = _measuredWidths!;
    final visible = <int>{for (var i = 0; i < totalChildren; i++) i};
    var totalWidth = widths.fold<double>(0, (sum, width) => sum + width);

    final orderedHide = <int>[
      ...widget.hidePriority.where((i) => i >= 0 && i < totalChildren),
      ...List<int>.generate(
        totalChildren,
        (index) => index,
      ).where((index) => !widget.hidePriority.contains(index)),
    ];

    for (final index in orderedHide) {
      if (totalWidth <= maxWidth) break;
      if (visible.length <= minVisible) break;
      if (!visible.contains(index)) continue;
      visible.remove(index);
      totalWidth -= widths[index];
    }

    return List<int>.generate(
      totalChildren,
      (index) => index,
    ).where((index) => visible.contains(index)).toList();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleIndexes = _buildVisibleIndexes(constraints.maxWidth);
        return Stack(
          children: [
            Offstage(
              offstage: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  widget.children.length,
                  (index) => KeyedSubtree(
                    key: _measureKeys[index],
                    child: widget.children[index],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: widget.mainAxisSize,
              children: [
                for (final index in visibleIndexes) widget.children[index],
              ],
            ),
          ],
        );
      },
    );
  }
}
