import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/tv_menu_support.dart';
import 'package:kazumi/services/platform/tv_service.dart';

/// Stable keyed row state follows its rule while the list order changes.
class TvRuleRowNavigation extends StatefulWidget {
  const TvRuleRowNavigation({
    super.key,
    required this.builder,
    required this.onMove,
    this.canSort = false,
    this.moreEnabled = true,
    this.selecting = false,
  });
  final Widget Function(
    FocusNode row,
    FocusNode more,
    FocusNode sort,
    bool sorting,
    VoidCallback toggleSorting,
  )
  builder;
  final Future<void> Function(int delta) onMove;
  final bool canSort;
  final bool moreEnabled;
  final bool selecting;

  @override
  State<TvRuleRowNavigation> createState() => _TvRuleRowNavigationState();
}

class _TvRuleRowNavigationState extends State<TvRuleRowNavigation> {
  final _row = FocusNode(debugLabel: 'TV rule row');
  final _more = FocusNode(debugLabel: 'TV rule more');
  final _sort = FocusNode(debugLabel: 'TV rule sort');
  bool _sorting = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKey);
  }

  bool _finishForBack() {
    if (!_sorting || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    _finish();
    return true;
  }

  void _finish() {
    TvMenuSupport.unregister(_finishForBack);
    if (mounted) setState(() => _sorting = false);
  }

  void _toggleSorting() {
    if (_sorting) {
      _finish();
    } else if (TvService.isTelevision && widget.canSort && !widget.selecting) {
      setState(() => _sorting = true);
      // Share the existing temporary-interaction Back layer: one Back ends
      // sorting, and cannot also leave the settings route or enter its rail.
      TvMenuSupport.register(_finishForBack);
      _sort.requestFocus();
    }
  }

  Future<void> _move(int delta) async {
    if (_saving) return;
    _saving = true;
    try {
      await widget.onMove(delta);
    } finally {
      _saving = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_sorting || _sort.context == null) return;
        _sort.requestFocus();
        Scrollable.ensureVisible(
          _row.context!,
          alignmentPolicy: delta < 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
              : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    }
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (!TvService.isTelevision ||
        widget.selecting ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final targets = [_row, _more, if (widget.canSort) _sort];
    final index = targets.indexWhere((node) => node.hasPrimaryFocus);
    if (index < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_sorting) {
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        _move(key == LogicalKeyboardKey.arrowUp ? -1 : 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.escape) {
        if (event is KeyDownEvent) _finish();
        return KeyEventResult.handled;
      }
      // Android Back may also deliver a keyboard event before its route-pop
      // notification. Let PopScope end sorting so that event cannot pop twice.
      if (key == LogicalKeyboardKey.goBack) return KeyEventResult.ignored;
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      if (index == 0 && key == LogicalKeyboardKey.arrowLeft) {
        return KeyEventResult.ignored;
      }
      final next = index + (key == LogicalKeyboardKey.arrowRight ? 1 : -1);
      if (next >= 0 &&
          next < targets.length &&
          targets[next].context != null &&
          targets[next].canRequestFocus) {
        targets[next].requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (index == 2 &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA)) {
      if (event is KeyDownEvent) _toggleSorting();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final policy = FocusTraversalGroup.of(context);
      final scope = _row.nearestScope;
      if (scope != null) policy.invalidateScopeData(scope);
      if (index > 0) _row.requestFocus();
      policy.inDirection(
        _row,
        key == LogicalKeyboardKey.arrowUp
            ? TraversalDirection.up
            : TraversalDirection.down,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(TvRuleRowNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sorting && (!widget.canSort || widget.selecting)) {
      TvMenuSupport.unregister(_finishForBack);
      _sorting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _more.skipTraversal = TvService.isTelevision && !widget.selecting;
    _sort.skipTraversal = TvService.isTelevision;
    _more.canRequestFocus = widget.moreEnabled;
    _sort.canRequestFocus = widget.canSort;
    return PopScope(
      canPop: !_sorting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sorting) TvMenuSupport.closeForBack();
      },
      child: widget.builder(_row, _more, _sort, _sorting, _toggleSorting),
    );
  }

  @override
  void dispose() {
    TvMenuSupport.unregister(_finishForBack);
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKey);
    _row.dispose();
    _more.dispose();
    _sort.dispose();
    super.dispose();
  }
}
