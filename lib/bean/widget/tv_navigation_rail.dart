import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/tv_input_support.dart';
import 'package:kazumi/services/platform/tv_service.dart';

/// Up/Down stays within the rail, including at its first and last controls.
class TvNavigationRail extends StatefulWidget {
  const TvNavigationRail({super.key, required this.child});
  final Widget child;

  /// Navigate an explicitly ordered rail without falling through at its ends.
  static bool moveWithin(List<FocusNode> nodes, TraversalDirection direction) {
    if (!TvService.isTelevision ||
        (direction != TraversalDirection.up &&
            direction != TraversalDirection.down)) {
      return false;
    }
    final index = nodes.indexWhere((node) => node.hasPrimaryFocus);
    if (index < 0) return false;
    final next = (index + (direction == TraversalDirection.down ? 1 : -1))
        .clamp(0, nodes.length - 1);
    nodes[next].requestFocus();
    final targetContext = nodes[next].context;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        alignmentPolicy: direction == TraversalDirection.up
            ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
    return true;
  }

  @override
  State<TvNavigationRail> createState() => _TvNavigationRailState();
}

class _TvNavigationRailState extends State<TvNavigationRail> {
  final _scope = FocusScopeNode(
    debugLabel: 'TV navigation rail',
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  bool _move(TraversalDirection direction) {
    if (!TvService.isTelevision ||
        !_scope.hasFocus ||
        (direction != TraversalDirection.up &&
            direction != TraversalDirection.down)) {
      return false;
    }
    final nodes =
        _scope.traversalDescendants.where((n) => n is! FocusScopeNode).toList()
          ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    return TvNavigationRail.moveWithin(nodes, direction);
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    node: _scope,
    child: TvDirectionalScope(onDirection: _move, child: widget.child),
  );
}
