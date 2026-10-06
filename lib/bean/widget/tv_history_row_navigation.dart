import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/platform/tv_service.dart';

/// Rows are the vertical navigation targets; their actions are entered sideways.
class TvHistoryRowNavigation extends StatefulWidget {
  const TvHistoryRowNavigation({
    super.key,
    required this.builder,
    this.editing = false,
  });

  final Widget Function(
    FocusNode row,
    FocusNode play,
    FocusNode more,
    FocusNode delete,
  )
  builder;
  final bool editing;

  @override
  State<TvHistoryRowNavigation> createState() => _TvHistoryRowNavigationState();
}

class _TvHistoryRowNavigationState extends State<TvHistoryRowNavigation> {
  final _row = FocusNode(debugLabel: 'TV history row');
  final _play = FocusNode(debugLabel: 'TV history play');
  final _more = FocusNode(debugLabel: 'TV history more');
  final _delete = FocusNode(debugLabel: 'TV history delete');

  @override
  void initState() {
    super.initState();
    // MenuAnchor's shortcuts can otherwise consume Left before the row sees it.
    FocusManager.instance.addEarlyKeyEventHandler(_handleKey);
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (!TvService.isTelevision ||
        widget.editing ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final targets = [_row, _play, _more];
    final index = targets.indexWhere(
      (target) => target == FocusManager.instance.primaryFocus,
    );
    // Popup menus and dialogs retain their own navigation.
    if (index < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowLeft) {
      final next = index + (key == LogicalKeyboardKey.arrowRight ? 1 : -1);
      if (next >= 0 && next < targets.length && targets[next].canRequestFocus) {
        targets[next].requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final policy = FocusTraversalGroup.of(context);
      final scope = _row.nearestScope;
      // Clear this on every vertical move: reversing direction can otherwise
      // restore an action from the policy's history even with skipTraversal.
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
  Widget build(BuildContext context) {
    // Explicit Left/Right can still request these nodes; vertical traversal skips
    // them, avoiding overlapping full-row and button rectangles as candidates.
    _play.skipTraversal = TvService.isTelevision;
    _more.skipTraversal = TvService.isTelevision;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: widget.builder(_row, _play, _more, _delete),
    );
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKey);
    _row.dispose();
    _play.dispose();
    _more.dispose();
    _delete.dispose();
    super.dispose();
  }
}
